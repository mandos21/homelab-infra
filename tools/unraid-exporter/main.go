package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"math"
	"net/http"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

const graphQLQuery = `query UnraidExporterArrayMetrics {
  array {
    state
    capacity {
      disks {
        free
        used
        total
      }
    }
    disks {
      name
      size
      status
      temp
    }
  }
}`

type config struct {
	graphQLURL    string
	apiKey        string
	listenAddr    string
	scrapeTimeout time.Duration
}

type exporter struct {
	client *http.Client
	config config
}

type graphQLRequest struct {
	Query string `json:"query"`
}

type graphQLResponse struct {
	Data   graphQLData    `json:"data"`
	Errors []graphQLError `json:"errors"`
}

type graphQLData struct {
	Array arrayData `json:"array"`
}

type graphQLError struct {
	Message string `json:"message"`
}

type arrayData struct {
	State    string       `json:"state"`
	Capacity capacityData `json:"capacity"`
	Disks    []diskData   `json:"disks"`
}

type capacityData struct {
	Disks capacityDiskData `json:"disks"`
}

type capacityDiskData struct {
	Free  flexibleFloat `json:"free"`
	Used  flexibleFloat `json:"used"`
	Total flexibleFloat `json:"total"`
}

type diskData struct {
	Name   string        `json:"name"`
	Size   flexibleFloat `json:"size"`
	Status string        `json:"status"`
	Temp   flexibleFloat `json:"temp"`
}

type flexibleFloat struct {
	value float64
	valid bool
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		slog.Error("invalid configuration", "err", err)
		os.Exit(1)
	}

	exp := exporter{
		client: &http.Client{Timeout: cfg.scrapeTimeout + 2*time.Second},
		config: cfg,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/metrics", exp.handleMetrics)
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})

	server := &http.Server{
		Addr:              cfg.listenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	slog.Info("starting unraid exporter", "listen_addr", cfg.listenAddr, "graphql_url", cfg.graphQLURL)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		slog.Error("server stopped", "err", err)
		os.Exit(1)
	}
}

func loadConfig() (config, error) {
	cfg := config{
		graphQLURL:    strings.TrimSpace(os.Getenv("UNRAID_GRAPHQL_URL")),
		apiKey:        strings.TrimSpace(os.Getenv("UNRAID_API_KEY")),
		listenAddr:    getenvDefault("LISTEN_ADDR", ":9108"),
		scrapeTimeout: 10 * time.Second,
	}

	if raw := strings.TrimSpace(os.Getenv("SCRAPE_TIMEOUT")); raw != "" {
		timeout, err := time.ParseDuration(raw)
		if err != nil {
			return config{}, fmt.Errorf("parse SCRAPE_TIMEOUT: %w", err)
		}
		cfg.scrapeTimeout = timeout
	}

	if cfg.graphQLURL == "" {
		return config{}, errors.New("UNRAID_GRAPHQL_URL is required")
	}
	if cfg.apiKey == "" {
		return config{}, errors.New("UNRAID_API_KEY is required")
	}

	return cfg, nil
}

func (e exporter) handleMetrics(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	ctx, cancel := context.WithTimeout(r.Context(), e.config.scrapeTimeout)
	defer cancel()

	data, err := e.queryArray(ctx)
	duration := time.Since(start).Seconds()

	var buf bytes.Buffer
	writer := newMetricWriter(&buf)
	writer.writeGauge("unraid_exporter_build_info", "Static build information for the Unraid exporter.", map[string]string{"version": "v0.1.0"}, 1)
	writer.writeGauge("unraid_up", "Whether the Unraid GraphQL API scrape succeeded.", nil, boolFloat(err == nil))
	writer.writeGauge("unraid_api_query_duration_seconds", "Duration of the Unraid GraphQL API query in seconds.", nil, duration)

	if err == nil || data.Array.State != "" || len(data.Array.Disks) > 0 {
		writeArrayMetrics(writer, data.Array)
	}

	if err != nil {
		slog.Warn("scrape failed", "err", err)
	}

	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(buf.Bytes())
}

func (e exporter) queryArray(ctx context.Context) (graphQLData, error) {
	body, err := json.Marshal(graphQLRequest{Query: graphQLQuery})
	if err != nil {
		return graphQLData{}, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, e.config.graphQLURL, bytes.NewReader(body))
	if err != nil {
		return graphQLData{}, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("x-api-key", e.config.apiKey)

	resp, err := e.client.Do(req)
	if err != nil {
		return graphQLData{}, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return graphQLData{}, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return graphQLData{}, fmt.Errorf("graphql status %d: %s", resp.StatusCode, strings.TrimSpace(string(respBody)))
	}

	var decoded graphQLResponse
	if err := json.Unmarshal(respBody, &decoded); err != nil {
		return graphQLData{}, fmt.Errorf("decode graphql response: %w", err)
	}
	if len(decoded.Errors) > 0 {
		return decoded.Data, fmt.Errorf("graphql error: %s", decoded.Errors[0].Message)
	}

	return decoded.Data, nil
}

func writeArrayMetrics(writer *metricWriter, array arrayData) {
	state := strings.TrimSpace(array.State)
	if state != "" {
		writer.writeGauge("unraid_array_state", "Current Unraid array state as a labelled gauge.", map[string]string{"state": state}, 1)
	}

	writer.writeOptionalGauge("unraid_array_capacity_bytes", "Unraid array disk capacity in bytes.", map[string]string{"type": "free"}, array.Capacity.Disks.Free)
	writer.writeOptionalGauge("unraid_array_capacity_bytes", "Unraid array disk capacity in bytes.", map[string]string{"type": "used"}, array.Capacity.Disks.Used)
	writer.writeOptionalGauge("unraid_array_capacity_bytes", "Unraid array disk capacity in bytes.", map[string]string{"type": "total"}, array.Capacity.Disks.Total)

	for _, disk := range array.Disks {
		name := strings.TrimSpace(disk.Name)
		if name == "" {
			continue
		}
		status := strings.TrimSpace(disk.Status)
		labels := map[string]string{"disk": name, "status": status}
		writer.writeOptionalGauge("unraid_disk_size_bytes", "Unraid disk size in bytes.", labels, disk.Size)
		writer.writeOptionalGauge("unraid_disk_temperature_celsius", "Unraid disk temperature in Celsius.", labels, disk.Temp)
		if status != "" {
			writer.writeGauge("unraid_disk_status", "Current Unraid disk status as a labelled gauge.", labels, 1)
		}
	}
}

type metricWriter struct {
	buf  *bytes.Buffer
	seen map[string]struct{}
}

func newMetricWriter(buf *bytes.Buffer) *metricWriter {
	return &metricWriter{
		buf:  buf,
		seen: map[string]struct{}{},
	}
}

func (w *metricWriter) writeOptionalGauge(name, help string, labels map[string]string, value flexibleFloat) {
	if !value.valid || math.IsNaN(value.value) || math.IsInf(value.value, 0) {
		return
	}
	w.writeGauge(name, help, labels, value.value)
}

func (w *metricWriter) writeGauge(name, help string, labels map[string]string, value float64) {
	if _, ok := w.seen[name]; !ok {
		w.buf.WriteString("# HELP ")
		w.buf.WriteString(name)
		w.buf.WriteByte(' ')
		w.buf.WriteString(help)
		w.buf.WriteByte('\n')
		w.buf.WriteString("# TYPE ")
		w.buf.WriteString(name)
		w.buf.WriteString(" gauge\n")
		w.seen[name] = struct{}{}
	}
	w.buf.WriteString(name)
	writeLabels(w.buf, labels)
	w.buf.WriteByte(' ')
	w.buf.WriteString(strconv.FormatFloat(value, 'f', -1, 64))
	w.buf.WriteByte('\n')
}

func writeLabels(buf *bytes.Buffer, labels map[string]string) {
	if len(labels) == 0 {
		return
	}
	first := true
	buf.WriteByte('{')
	keys := make([]string, 0, len(labels))
	for key := range labels {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		if !first {
			buf.WriteByte(',')
		}
		first = false
		value := labels[key]
		buf.WriteString(key)
		buf.WriteString("=\"")
		buf.WriteString(escapeLabel(value))
		buf.WriteByte('"')
	}
	buf.WriteByte('}')
}

func escapeLabel(value string) string {
	value = strings.ReplaceAll(value, "\\", "\\\\")
	value = strings.ReplaceAll(value, "\n", "\\n")
	value = strings.ReplaceAll(value, "\"", "\\\"")
	return value
}

func boolFloat(value bool) float64 {
	if value {
		return 1
	}
	return 0
}

func getenvDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func (f *flexibleFloat) UnmarshalJSON(data []byte) error {
	if bytes.Equal(data, []byte("null")) {
		*f = flexibleFloat{}
		return nil
	}

	var number float64
	if err := json.Unmarshal(data, &number); err == nil {
		*f = flexibleFloat{value: number, valid: true}
		return nil
	}

	var text string
	if err := json.Unmarshal(data, &text); err != nil {
		return err
	}
	text = strings.TrimSpace(text)
	if text == "" || text == "*" {
		*f = flexibleFloat{}
		return nil
	}
	parsed, err := strconv.ParseFloat(text, 64)
	if err != nil {
		*f = flexibleFloat{}
		return nil
	}
	*f = flexibleFloat{value: parsed, valid: true}
	return nil
}
