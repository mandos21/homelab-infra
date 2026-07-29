package main

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
)

func TestGraphQLResponseParsesDocumentedArrayShape(t *testing.T) {
	payload := []byte(`{
		"data": {
			"array": {
				"state": "STARTED",
				"capacity": {
					"disks": {
						"free": 1000,
						"used": "2000",
						"total": 3000
					}
				},
				"disks": [
					{"name": "disk1", "size": "4000", "status": "DISK_OK", "temp": "35"},
					{"name": "parity", "size": 4000, "status": "DISK_OK", "temp": null}
				]
			}
		}
	}`)

	var response graphQLResponse
	if err := json.Unmarshal(payload, &response); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}

	if response.Data.Array.State != "STARTED" {
		t.Fatalf("state = %q, want STARTED", response.Data.Array.State)
	}
	if !response.Data.Array.Capacity.Disks.Used.valid || response.Data.Array.Capacity.Disks.Used.value != 2000 {
		t.Fatalf("used capacity did not parse as flexible float: %#v", response.Data.Array.Capacity.Disks.Used)
	}
	if response.Data.Array.Disks[1].Temp.valid {
		t.Fatalf("null temp should not be valid")
	}
}

func TestWriteArrayMetricsSkipsMissingTemperature(t *testing.T) {
	array := arrayData{
		State: "STARTED",
		Capacity: capacityData{Disks: capacityDiskData{
			Free: flexibleFloat{value: 1000, valid: true},
		}},
		Disks: []diskData{
			{Name: "disk1", Status: "DISK_OK", Size: flexibleFloat{value: 4000, valid: true}, Temp: flexibleFloat{value: 35, valid: true}},
			{Name: "parity", Status: "DISK_OK", Size: flexibleFloat{value: 4000, valid: true}},
		},
	}

	var output bytes.Buffer
	writeArrayMetrics(newMetricWriter(&output), array)

	metrics := output.String()
	if !strings.Contains(metrics, `unraid_array_state{state="STARTED"} 1`) {
		t.Fatalf("missing array state metric:\n%s", metrics)
	}
	if !strings.Contains(metrics, `unraid_disk_temperature_celsius`) {
		t.Fatalf("missing disk temperature metric:\n%s", metrics)
	}
	if strings.Contains(metrics, `unraid_disk_temperature_celsius{disk="parity"`) {
		t.Fatalf("missing parity temperature should be skipped:\n%s", metrics)
	}
}
