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
					"kilobytes": {
						"free": 1024,
						"used": "2048",
						"total": 3072
					}
				},
				"parityCheckStatus": {
					"status": "COMPLETED",
					"progress": 0,
					"speed": "0",
					"duration": 197076,
					"correcting": null,
					"paused": null,
					"running": null
				},
				"disks": [
					{"name": "disk1", "size": "4000", "fsSize": "3900", "fsUsed": "2000", "status": "DISK_OK", "temp": "35", "numErrors": 0, "isSpinning": true, "type": "DATA"}
				],
				"parities": [
					{"name": "parity", "size": 4000, "status": "DISK_OK", "temp": null, "numErrors": 0, "isSpinning": false, "type": "PARITY"}
				],
				"caches": []
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
	if !response.Data.Array.Capacity.Kilobytes.Used.valid || response.Data.Array.Capacity.Kilobytes.Used.value != 2048 {
		t.Fatalf("used capacity did not parse as flexible float: %#v", response.Data.Array.Capacity.Kilobytes.Used)
	}
	if response.Data.Array.Parities[0].Temp.valid {
		t.Fatalf("null temp should not be valid")
	}
	if !response.Data.Array.Disks[0].IsSpinning.valid || !response.Data.Array.Disks[0].IsSpinning.value {
		t.Fatalf("isSpinning did not parse as flexible bool: %#v", response.Data.Array.Disks[0].IsSpinning)
	}
}

func TestWriteArrayMetricsSkipsMissingTemperature(t *testing.T) {
	array := arrayData{
		State: "STARTED",
		Capacity: capacityData{Kilobytes: capacityKilobyteData{
			Free: flexibleFloat{value: 1024, valid: true},
		}},
		ParityCheckStatus: parityCheckStatus{
			Status:   "COMPLETED",
			Progress: flexibleFloat{value: 50, valid: true},
		},
		Disks: []diskData{
			{Name: "disk1", Status: "DISK_OK", Type: "DATA", Size: flexibleFloat{value: 4000, valid: true}, Temp: flexibleFloat{value: 35, valid: true}, IsSpinning: flexibleBool{value: true, valid: true}},
		},
		Parities: []diskData{
			{Name: "parity", Status: "DISK_OK", Type: "PARITY", Size: flexibleFloat{value: 4000, valid: true}},
		},
	}

	var output bytes.Buffer
	writeArrayMetrics(newMetricWriter(&output), array)

	metrics := output.String()
	if !strings.Contains(metrics, `unraid_array_state{state="STARTED"} 1`) {
		t.Fatalf("missing array state metric:\n%s", metrics)
	}
	if !strings.Contains(metrics, `unraid_array_capacity_bytes{type="free"} 1048576`) {
		t.Fatalf("capacity KiB should be converted to bytes:\n%s", metrics)
	}
	if !strings.Contains(metrics, `unraid_disk_size_bytes{disk="disk1",status="DISK_OK",type="DATA"} 4096000`) {
		t.Fatalf("disk KiB should be converted to bytes:\n%s", metrics)
	}
	if !strings.Contains(metrics, `unraid_disk_temperature_celsius`) {
		t.Fatalf("missing disk temperature metric:\n%s", metrics)
	}
	if strings.Contains(metrics, `unraid_disk_temperature_celsius{disk="parity"`) {
		t.Fatalf("missing parity temperature should be skipped:\n%s", metrics)
	}
	if !strings.Contains(metrics, `unraid_parity_check_progress_ratio 0.5`) {
		t.Fatalf("parity progress percent should be converted to ratio:\n%s", metrics)
	}
}
