#!/bin/bash

echo "🔍 TestApp API接続詳細診断..."

echo ""
echo "1. ポート8765の詳細確認:"
echo "   リスニング状態:"
netstat -an | grep 8765 || echo "   ❌ ポート8765でリスニングしているプロセスなし"
echo ""
echo "   プロセス詳細:"
lsof -i :8765 || echo "   ❌ ポート8765を使用しているプロセスなし"

echo ""
echo "2. 手動API接続テスト:"
echo "   ヘルスチェック:"
curl -v --connect-timeout 10 http://localhost:8765/api/health 2>&1 || echo "   ❌ 接続失敗"

echo ""
echo "3. 代替ホスト名での接続テスト:"
echo "   127.0.0.1での接続:"
curl --connect-timeout 5 http://127.0.0.1:8765/api/health 2>/dev/null && echo "   ✅ 127.0.0.1で接続成功" || echo "   ❌ 127.0.0.1でも接続失敗"

echo ""
echo "4. TestAppプロセス詳細:"
ps aux | grep -i testapp | grep -v grep

echo ""
echo "5. ネットワークスタック確認:"
echo "   localhost解決:"
nslookup localhost
echo ""
echo "   /etc/hosts の localhost設定:"
grep localhost /etc/hosts

echo ""
echo "6. システムファイアウォール状態:"
sudo pfctl -s info 2>/dev/null | head -5 || echo "   ファイアウォール情報取得不可"

echo ""
echo "7. macOS Application Firewall確認:"
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "   Application Firewall状態取得不可"
