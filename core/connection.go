package core

import (
	"slices"

	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func handleGetTraffic(params TrafficParams) Traffic {
	up, down := statistic.DefaultManager.NowTraffic(params.OnlyProxy)
	return Traffic{Up: up, Down: down}
}

func handleGetTotalTraffic(params TrafficParams) Traffic {
	up, down := statistic.DefaultManager.TotalTraffic(params.OnlyProxy)
	return Traffic{Up: up, Down: down}
}

func handleResetTraffic() {
	statistic.DefaultManager.ResetStatistic()
}

func handleGetConnections() *statistic.Snapshot {
	return statistic.DefaultManager.Snapshot()
}

func handleGetConnectionCount() int {
	count := 0
	statistic.DefaultManager.Range(func(statistic.Tracker) bool {
		count++
		return true
	})
	return count
}

func handleGetActiveOutboundPaths() []constant.Chain {
	proxies := tunnel.AllProxies()
	paths := make([]constant.Chain, 0)
	seen := make(map[[2]string][]constant.Chain)
	statistic.DefaultManager.Range(func(tracker statistic.Tracker) bool {
		info := tracker.Info()
		chain := info.Chain
		if info.Metadata.Type == constant.INNER || len(chain) == 0 || chain[0] == "" {
			return true
		}
		if proxy := proxies[chain[0]]; proxy != nil {
			switch proxy.Type() {
			case constant.Reject, constant.RejectDrop, constant.Pass, constant.PassRule:
				return true
			}
		}
		ends := [2]string{chain[0], chain[len(chain)-1]}
		if !slices.ContainsFunc(seen[ends], func(previous constant.Chain) bool {
			return slices.Equal(previous, chain)
		}) {
			seen[ends] = append(seen[ends], chain)
			paths = append(paths, chain)
		}
		return true
	})
	slices.SortFunc(paths, slices.Compare)
	return paths
}

func handleCloseConnections() {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		return true
	})
}

func handleResetConnections() {
	resolver.ResetConnection()
}

// A network change clears rather than waits out the TTLs: mihomo serves an
// expired entry once more before it refreshes it.
func handleClearDnsCache() {
	configMu.Lock()
	defer configMu.Unlock()
	dns.ClearAll()
}

// handleNetworkChanged is how the desktop host reports a new network, which
// Android's NetworkObserver reports through handleResetNetwork.
func handleNetworkChanged() {
	handleClearDnsCache()
}

// A connection that went out over a network the device has left hangs until
// TCP gives up on it, and so do the DNS clients' pooled connections.
func handleResetNetwork() {
	handleCloseConnections()
	handleNetworkChanged()
}

// A connection that is already gone is closed as far as the host is concerned.
func handleCloseConnection(params IDParams) error {
	if c := statistic.DefaultManager.Get(params.ID); c != nil {
		_ = c.Close()
	}
	return nil
}
