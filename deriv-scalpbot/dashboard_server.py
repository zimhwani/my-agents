"""
Deriv ScalpBot - Dashboard API Server
Serves bot performance data and logs to the React dashboard
Run: python3 dashboard_server.py
"""

import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PERF_FILE = os.path.join(BASE_DIR, 'data', 'performance_data.json')
LOG_FILE = os.path.join(BASE_DIR, 'deriv_scalpbot.log')
PORT = 5001


class DashboardHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        pass  # Suppress default access logs

    def send_json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(body))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.end_headers()

    def do_GET(self):
        path = urlparse(self.path).path

        if path in ('/', '/dashboard.html'):
            self.handle_html()
        elif path == '/api/performance':
            self.handle_performance()
        elif path == '/api/logs':
            self.handle_logs()
        elif path == '/api/status':
            self.handle_status()
        else:
            self.send_json({'error': 'Not found'}, 404)

    def handle_html(self):
        html_path = os.path.join(BASE_DIR, 'dashboard.html')
        try:
            with open(html_path, 'rb') as f:
                body = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(body))
            self.end_headers()
            self.wfile.write(body)
        except FileNotFoundError:
            self.send_json({'error': 'dashboard.html not found'}, 404)

    def handle_performance(self):
        try:
            with open(PERF_FILE, 'r') as f:
                data = json.load(f)

            # Compute summary totals
            trade_history = data.get('trade_history', [])
            total_trades = len(trade_history)
            wins = sum(1 for t in trade_history if t.get('profit', 0) > 0)
            total_pnl = sum(t.get('profit', 0) for t in trade_history)
            win_rate = (wins / total_trades * 100) if total_trades > 0 else 0

            # Strategy performance list
            strategies = []
            for name, stats in data.get('strategy_stats', {}).items():
                t = stats.get('trades', 0)
                w = stats.get('wins', 0)
                pnl = stats.get('total_pnl', 0)
                stake = stats.get('total_stake', 0)
                strategies.append({
                    'strategy': name,
                    'trades': t,
                    'wins': w,
                    'losses': stats.get('losses', 0),
                    'win_rate': round(w / t * 100, 1) if t > 0 else 0,
                    'total_pnl': round(pnl, 2),
                    'roi': round(pnl / stake * 100, 1) if stake > 0 else 0,
                })

            # Symbol performance list
            symbols = []
            for name, stats in data.get('symbol_stats', {}).items():
                t = stats.get('trades', 0)
                w = stats.get('wins', 0)
                pnl = stats.get('total_pnl', 0)
                stake = stats.get('total_stake', 0)
                symbols.append({
                    'symbol': name,
                    'trades': t,
                    'wins': w,
                    'losses': stats.get('losses', 0),
                    'win_rate': round(w / t * 100, 1) if t > 0 else 0,
                    'total_pnl': round(pnl, 2),
                    'roi': round(pnl / stake * 100, 1) if stake > 0 else 0,
                })

            # Recent trades (last 50)
            recent = sorted(trade_history, key=lambda x: x.get('timestamp', ''), reverse=True)[:50]

            self.send_json({
                'summary': {
                    'total_trades': total_trades,
                    'wins': wins,
                    'losses': total_trades - wins,
                    'win_rate': round(win_rate, 1),
                    'total_pnl': round(total_pnl, 2),
                },
                'strategies': strategies,
                'symbols': symbols,
                'recent_trades': recent,
            })

        except FileNotFoundError:
            self.send_json({
                'summary': {'total_trades': 0, 'wins': 0, 'losses': 0, 'win_rate': 0, 'total_pnl': 0},
                'strategies': [],
                'symbols': [],
                'recent_trades': [],
                'note': 'No data yet — start the bot first'
            })
        except Exception as e:
            self.send_json({'error': str(e)}, 500)

    def handle_logs(self):
        try:
            with open(LOG_FILE, 'r') as f:
                lines = f.readlines()
            self.send_json({'lines': [l.rstrip() for l in lines[-150:]]})
        except FileNotFoundError:
            self.send_json({'lines': ['No log file yet — start the bot first']})
        except Exception as e:
            self.send_json({'error': str(e)}, 500)

    def handle_status(self):
        perf_exists = os.path.exists(PERF_FILE)
        log_exists = os.path.exists(LOG_FILE)
        self.send_json({
            'server': 'running',
            'data_file': perf_exists,
            'log_file': log_exists,
        })


if __name__ == '__main__':
    server = HTTPServer(('localhost', PORT), DashboardHandler)
    print(f"Dashboard API running at http://localhost:{PORT}")
    print(f"Open dashboard.html in your browser")
    print("Press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
