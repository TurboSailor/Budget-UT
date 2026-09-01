// Package rates fetches daily FX quotes expressed as "units per USD" — the
// same convention the currencies table already stores in currencies.rate.
package rates

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	// primaryURL needs no API key and returns every fiat code we care about.
	primaryURL = "https://open.er-api.com/v6/latest/USD"
	// fallbackURL covers the ~30 ECB reference currencies.
	fallbackURL = "https://api.frankfurter.app/latest?from=USD"

	// Base is the pivot: all rates are units of X per 1 USD.
	Base = "USD"
)

var client = &http.Client{Timeout: 15 * time.Second}

// Fetch pulls fresh rates from the primary source and falls back to the
// secondary one. source is the human-readable origin (host) of the data that
// was actually used.
func Fetch(ctx context.Context) (base string, out map[string]float64, source string, err error) {
	out, err1 := fetchERAPI(ctx)
	if err1 == nil {
		return Base, out, host(primaryURL), nil
	}
	out, err2 := fetchFrankfurter(ctx)
	if err2 == nil {
		return Base, out, host(fallbackURL), nil
	}
	return Base, nil, "", fmt.Errorf("rates unavailable: %s: %v; %s: %v",
		host(primaryURL), err1, host(fallbackURL), err2)
}

func fetchERAPI(ctx context.Context) (map[string]float64, error) {
	var body struct {
		Result string             `json:"result"`
		Base   string             `json:"base_code"`
		Rates  map[string]float64 `json:"rates"`
		Error  string             `json:"error-type"`
	}
	if err := getJSON(ctx, primaryURL, &body); err != nil {
		return nil, err
	}
	if body.Result != "success" {
		if body.Error != "" {
			return nil, fmt.Errorf("result=%q (%s)", body.Result, body.Error)
		}
		return nil, fmt.Errorf("result=%q", body.Result)
	}
	if body.Base != "" && !strings.EqualFold(body.Base, Base) {
		return nil, fmt.Errorf("unexpected base %q", body.Base)
	}
	return clean(body.Rates)
}

func fetchFrankfurter(ctx context.Context) (map[string]float64, error) {
	var body struct {
		Base  string             `json:"base"`
		Rates map[string]float64 `json:"rates"`
	}
	if err := getJSON(ctx, fallbackURL, &body); err != nil {
		return nil, err
	}
	if body.Base != "" && !strings.EqualFold(body.Base, Base) {
		return nil, fmt.Errorf("unexpected base %q", body.Base)
	}
	return clean(body.Rates)
}

func getJSON(ctx context.Context, url string, dst any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "budgetd/1 (+ubuntu-touch)")
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 4<<10))
		return fmt.Errorf("http %d", resp.StatusCode)
	}
	// Rate tables are ~30 KiB; cap the read so a hostile captive portal cannot
	// feed the daemon megabytes.
	return json.NewDecoder(io.LimitReader(resp.Body, 2<<20)).Decode(dst)
}

// clean normalizes codes to upper case, drops junk and guarantees the pivot is
// present with rate 1 (frankfurter omits the base).
func clean(in map[string]float64) (map[string]float64, error) {
	out := make(map[string]float64, len(in)+1)
	for code, rate := range in {
		code = strings.ToUpper(strings.TrimSpace(code))
		if code == "" || rate <= 0 {
			continue
		}
		out[code] = rate
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("empty rate table")
	}
	out[Base] = 1
	return out, nil
}

func host(rawURL string) string {
	s := strings.TrimPrefix(strings.TrimPrefix(rawURL, "https://"), "http://")
	if i := strings.IndexAny(s, "/?"); i >= 0 {
		s = s[:i]
	}
	return s
}
