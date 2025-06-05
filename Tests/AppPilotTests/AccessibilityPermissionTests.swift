import Testing
import Foundation
import ApplicationServices
@testable import AppPilot

@Suite("Accessibility Permission Tests")
struct AccessibilityPermissionTests {
    
    @Test("Check Accessibility Permissions")
    func testAccessibilityPermissions() async throws {
        print("🔍 アクセシビリティ権限チェック開始...")
        
        // 1. システムレベルでのアクセシビリティ権限確認
        let trusted = AXIsProcessTrusted()
        print("   AXIsProcessTrusted(): \(trusted)")
        
        if !trusted {
            print("   ❌ アクセシビリティ権限が付与されていません")
            print("   📋 解決方法:")
            print("      1. システム環境設定 > セキュリティとプライバシー > プライバシー")
            print("      2. アクセシビリティを選択")
            print("      3. Xcodeまたはテストランナーを追加/有効化")
            
            // 権限要求ダイアログを表示（concurrency-safe版）
            await MainActor.run {
                let promptKey = "AXTrustedCheckOptionPrompt" as CFString
                let options = [promptKey: true] as CFDictionary
                let trustedWithPrompt = AXIsProcessTrustedWithOptions(options)
                print("   📢 権限要求ダイアログ表示: \(trustedWithPrompt)")
            }
            
            return // 権限がない場合は早期終了
        }
        
        print("   ✅ アクセシビリティ権限は付与されています")
        
        // 2. 基本的なAXUIElement操作テスト
        print("\n🧪 基本的なAXUIElement操作テスト...")
        
        do {
            // システムワイドAXUIElementを取得
            let systemWideElement = AXUIElementCreateSystemWide()
            print("   ✅ AXUIElementCreateSystemWide() 成功")
            
            // アプリケーション一覧を取得
            var applicationList: CFTypeRef?
            let applicationsAttr = "AXApplications" as CFString
            let result = AXUIElementCopyAttributeValue(
                systemWideElement,
                applicationsAttr,
                &applicationList
            )
            
            if result == .success, let apps = applicationList as? [AXUIElement] {
                let appCount = apps.count
                print("   ✅ アプリケーション一覧取得成功: \(appCount)個のアプリ")
                
                // TestAppを探す
                for app in apps {
                    var title: CFTypeRef?
                    let titleAttr = "AXTitle" as CFString
                    let titleResult = AXUIElementCopyAttributeValue(app, titleAttr, &title)
                    
                    if titleResult == .success, let titleString = title as? String {
                        if titleString.contains("TestApp") || titleString.contains("AppMCP") {
                            print("   🎯 TestApp発見: \(titleString)")
                            
                            // TestAppのウィンドウを取得してみる
                            try await testTestAppWindows(appElement: app)
                            break
                        }
                    }
                }
            } else {
                print("   ❌ アプリケーション一覧取得失敗: \(result)")
            }
            
        } catch {
            print("   ❌ AXUIElement操作でエラー: \(error)")
        }
        
        // 3. AppPilot統合テスト
        print("\n🚀 AppPilot統合テスト...")
        await testAppPilotAccessibility()
    }
    
    private func testTestAppWindows(appElement: AXUIElement) async throws {
        print("      TestAppのウィンドウ情報を取得中...")
        
        var windows: CFTypeRef?
        let windowsAttr = "AXWindows" as CFString
        let windowsResult = AXUIElementCopyAttributeValue(appElement, windowsAttr, &windows)
        
        if windowsResult == .success, let windowArray = windows as? [AXUIElement] {
            print("      ✅ ウィンドウ数: \(windowArray.count)")
            
            for (index, window) in windowArray.enumerated() {
                var windowTitle: CFTypeRef?
                let titleAttr = "AXTitle" as CFString
                let titleResult = AXUIElementCopyAttributeValue(window, titleAttr, &windowTitle)
                
                var windowPosition: CFTypeRef?
                let positionAttr = "AXPosition" as CFString
                let positionResult = AXUIElementCopyAttributeValue(window, positionAttr, &windowPosition)
                
                var windowSize: CFTypeRef?
                let sizeAttr = "AXSize" as CFString
                let sizeResult = AXUIElementCopyAttributeValue(window, sizeAttr, &windowSize)
                
                let title = (titleResult == .success) ? (windowTitle as? String ?? "無題") : "不明"
                print("      ウィンドウ\(index + 1): \(title)")
                
                if positionResult == .success, sizeResult == .success {
                    print("         位置・サイズ情報取得成功")
                } else {
                    print("         位置・サイズ情報取得失敗")
                }
            }
        } else {
            print("      ❌ ウィンドウ情報取得失敗: \(windowsResult)")
        }
    }
    
    private func testAppPilotAccessibility() async {
        print("   AppPilotでのアクセシビリティテスト...")
        
        let discovery = TestAppDiscovery(config: TestConfiguration())
        
        do {
            // TestApp検出
            let app = try await discovery.findTestApp()
            print("   ✅ TestApp検出成功: \(app.name) (PID: \(app.id.pid))")
            
            let window = try await discovery.findTestAppWindow()
            print("   ✅ ウィンドウ検出成功: \(window.title ?? "無題")")
            
            // AppPilotでアクセシビリティドライバーをテスト
            let pilot = AppPilot()
            
            do {
                let axTree = try await pilot.accessibilityTree(window: window.id, depth: 1)
                print("   ✅ アクセシビリティツリー取得成功")
                print("      ルート要素: role=\(axTree.role ?? "不明"), title=\(axTree.title ?? "不明")")
            } catch {
                print("   ❌ アクセシビリティツリー取得失敗: \(error)")
            }
            
        } catch {
            print("   ❌ TestApp検出失敗: \(error)")
        }
    }
    
    @Test("Simple UI Event Test - fallback route")
    func testUIEventFallback() async throws {
        print("🖱️ UI Event fallback テスト...")
        
        let client = TestAppClient()
        let discovery = TestAppDiscovery(config: TestConfiguration())
        
        // 基本セットアップ
        let isHealthy = try await client.healthCheck()
        guard isHealthy else {
            print("❌ API not healthy")
            return
        }
        
        try await client.resetState()
        let _ = try await client.startSession()
        
        let readinessInfo = try await discovery.verifyTestAppReadiness()
        guard readinessInfo.isReady else {
            print("❌ TestApp not ready")
            return
        }
        
        let targets = try await client.getClickTargets()
        guard let firstTarget = targets.first else {
            print("❌ No targets available")
            return
        }
        
        print("🎯 UI_EVENT ルートでクリックテスト: \(firstTarget.label)")
        
        let pilot = AppPilot()
        
        do {
            // UI_EVENT ルートを明示的に指定
            let result = try await pilot.click(
                window: readinessInfo.window.id,
                at: Point(x: firstTarget.position.x, y: firstTarget.position.y),
                policy: .UNMINIMIZE(),
                route: .UI_EVENT  // UI_EVENT ルートを強制
            )
            
            print("✅ UI_EVENT クリック結果: \(result.success) via \(result.route)")
            
            if result.success {
                let isClicked = try await client.validateClickTarget(id: firstTarget.id)
                print("📊 ターゲット状態: \(isClicked ? "クリック済み" : "未クリック")")
            }
            
        } catch {
            print("❌ UI_EVENT クリック失敗: \(error)")
        }
        
        let _ = try await client.endSession()
        print("🖱️ UI Event fallback テスト完了")
    }
    
    @Test("Permission Status Check Only")
    func testPermissionStatusOnly() async throws {
        print("🔒 権限状態のみチェック...")
        
        let trusted = AXIsProcessTrusted()
        print("   アクセシビリティ権限: \(trusted ? "✅ 有効" : "❌ 無効")")
        
        if !trusted {
            print("   必要な手順:")
            print("   1. システム環境設定を開く")
            print("   2. セキュリティとプライバシー > プライバシー")
            print("   3. アクセシビリティを選択")
            print("   4. Xcodeを追加して有効化")
            print("   5. テストを再実行")
        }
        
        // CGEventSourceStateIDの権限もチェック
        print("   CGEventSource権限チェック...")
        let eventSource = CGEventSource(stateID: .hidSystemState)
        if eventSource != nil {
            print("   ✅ CGEventSource作成成功")
        } else {
            print("   ❌ CGEventSource作成失敗")
        }
        
        print("🔒 権限チェック完了")
    }
}

@Suite("Simple Integration Tests")
struct SimpleIntegrationTests {
    
    @Test("Basic TestApp Connection")
    func testBasicConnection() async throws {
        print("🔌 基本接続テスト...")
        
        let client = TestAppClient()
        
        // ヘルスチェック
        let isHealthy = try await client.healthCheck()
        print("   API Health: \(isHealthy ? "✅" : "❌")")
        
        if !isHealthy {
            print("   TestAppが起動していない可能性があります")
            return
        }
        
        // ターゲット取得
        let targets = try await client.getClickTargets()
        print("   Targets: \(targets.count)個")
        
        for target in targets {
            print("     - \(target.id): \(target.label) at (\(target.position.x), \(target.position.y))")
        }
        
        print("🔌 基本接続テスト完了")
    }
    
    @Test("Mock Driver Test")
    func testMockDrivers() async throws {
        print("🎭 Mock Driver テスト...")
        
        let mockUIEventDriver = MockUIEventDriver()
        let mockAccessibilityDriver = MockAccessibilityDriver()
        
        let pilot = AppPilot(
            accessibilityDriver: mockAccessibilityDriver,
            uiEventDriver: mockUIEventDriver
        )
        
        let testWindow = Window(
            id: WindowID(id: 100),
            title: "Mock Test",
            frame: CGRect(x: 100, y: 100, width: 800, height: 600),
            isMinimized: false,
            app: AppID(pid: 12345)
        )
        
        // UI_EVENT ルートでテスト
        do {
            let result = try await pilot.click(
                window: testWindow.id,
                at: Point(x: 200, y: 300),
                policy: .STAY_HIDDEN,
                route: .UI_EVENT
            )
            
            print("   Mock UI_EVENT クリック: \(result.success ? "✅" : "❌")")
            print("   Route: \(result.route)")
            
            let clickEvents = await mockUIEventDriver.getClickEvents()
            print("   Click events: \(clickEvents.count)")
            
        } catch {
            print("   ❌ Mock テスト失敗: \(error)")
        }
        
        print("🎭 Mock Driver テスト完了")
    }
}
