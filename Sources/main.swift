import AppKit
import QuartzCore

final class AppDelegate: NSObject,NSApplicationDelegate,NSWindowDelegate {
    var world: World!
    var arena: ArenaView!
    var panelView: ControlView!
    var overlay: PetWindow!
    var panel: ControlPanel!
    var status: NSStatusItem!
    var timer: Timer?
    var lastTime = CACurrentMediaTime()
    var lastUI: Double = 0
    var lastPaint: Double = 0
    var hidden = false
    var soundEnabled = UserDefaults.standard.bool(forKey:"soundEnabled")
    var localKeys: Any?
    var characterGallery:CharacterGallery?
    var reportPanel:NSPanel?
    var reportView:NSTextView?
    var lastSave:Double = 0
    var lastReport:Double = 0
    var saveBlocked=false
    var saveURL:URL {FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("DesktopCritters/ecology-v1.json")}
    func saveEcology() {
        guard !saveBlocked else {return}
        do {
            try FileManager.default.createDirectory(at:saveURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try world.saveData().write(to:saveURL,options:.atomic)
        } catch {world.say("本机存档失败，本次关闭后的状态可能丢失。",force:true)}
    }
    @objc func showReport() {
        if reportPanel == nil {
            let p=NSPanel(contentRect:NSRect(x:180,y:150,width:600,height:590),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
            p.title="今日战报 · 桌面有点脏";p.minSize=NSSize(width:600,height:590);p.isReleasedWhenClosed=false;p.level=NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue+2)
            let root=NSView(frame:NSRect(x:0,y:0,width:600,height:590));p.contentView=root
            let scroll=NSScrollView(frame:NSRect(x:18,y:68,width:564,height:504));scroll.hasVerticalScroller=true;scroll.autoresizingMask=[.width,.height]
            let text=NSTextView(frame:scroll.bounds);text.isEditable=false;text.isSelectable=true;text.font=NSFont.systemFont(ofSize:14);text.textContainerInset=NSSize(width:14,height:14);text.isVerticallyResizable=true;text.isHorizontallyResizable=false;text.autoresizingMask=[.width];text.textContainer?.widthTracksTextView=true
            scroll.documentView=text;root.addSubview(scroll);reportView=text
            let actions:[(String,Relations)]=[("让双方停火",.truce),("建交通商",.trade),("恢复交战",.hostile)]
            for (i,item) in actions.enumerated() {
                let b=ActionButton(item.0,frame:CGRect(x:18+i*190,y:18,width:180,height:34)){[weak self] in
                    guard let self=self else {return};self.world.setRelations(item.1,reason:"桌面主人调停");self.reportView?.string=self.world.reportText;self.saveEcology()
                };root.addSubview(b)
            }
            reportPanel=p
        }
        reportView?.string=world.reportText;reportPanel?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    var screen: NSScreen { NSScreen.main ?? NSScreen.screens[0] }

    func applicationDidFinishLaunching(_ notification:Notification) {
        // One app instance: launching the bundle a second time reveals its control card.
        let f = screen.visibleFrame
        world = World(width:f.width,height:f.height)
        if FileManager.default.fileExists(atPath:saveURL.path) {
            do {try world.restore(Data(contentsOf:saveURL))}
            catch {saveBlocked=true;world.say("旧存档读取失败，已保留原文件；当前临时运行。",force:true)}
        }
        world.antAvatarEnabled=CharacterLibrary.shared.enabled
        overlay = PetWindow(contentRect:f,styleMask:[.titled,.fullSizeContentView],backing:.buffered,defer:false)
        overlay.title = "桌面有点脏 · 虫群"
        overlay.titleVisibility = .hidden; overlay.titlebarAppearsTransparent=true
        overlay.standardWindowButton(.closeButton)?.isHidden=true
        overlay.standardWindowButton(.miniaturizeButton)?.isHidden=true
        overlay.standardWindowButton(.zoomButton)?.isHidden=true
        overlay.isMovable=false; overlay.setFrame(f,display:false)
        overlay.isOpaque=false; overlay.backgroundColor = .clear; overlay.hasShadow=false
        overlay.level = .floating; overlay.ignoresMouseEvents=true; overlay.acceptsMouseMovedEvents=true
        overlay.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications]
        overlay.isReleasedWhenClosed=false
        overlay.setAccessibilitySubrole(.standardWindow)
        arena = ArenaView(world:world,frame:CGRect(origin:.zero,size:f.size)); overlay.contentView=arena
        arena.autoresizingMask=[.width,.height]
        arena.onEscape = {[weak self] in self?.toCompanion()}
        arena.onTool = {[weak self] in self?.selectTool($0)}
        arena.onPause = {[weak self] in self?.togglePause()}
        panel = ControlPanel(contentRect:CGRect(x:f.maxX-346,y:f.maxY-760,width:324,height:734),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.title = "桌面有点脏 · 控制台"
        panel.isOpaque=false; panel.backgroundColor = .clear; panel.hasShadow=true
        panel.level=NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue+1)
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.canJoinAllApplications]; panel.hidesOnDeactivate=false
        panel.isReleasedWhenClosed=false; panel.delegate=self
        panelView = ControlView(world:world); panel.contentView=panelView
        panelView.soundEnabled=soundEnabled
        panelView.onCharacters = {[weak self] in self?.showCharacters()}
        panelView.onReport = {[weak self] in self?.showReport()}
        panelView.onStart = {[weak self] in self?.startRound()}
        panelView.onCompanion = {[weak self] in self?.toCompanion()}
        panelView.onPause = {[weak self] in self?.togglePause()}
        panelView.onHide = {[weak self] in self?.hidePanel()}
        panelView.onTool = {[weak self] in self?.selectTool($0)}
        panelView.onSound = {[weak self] in self?.toggleSound()}
        panelView.onFrame = {[weak self] in self?.toggleFrame()}
        panelView.onRate = {[weak self] in self?.changeRate()}
        panelView.onQuit = {NSApp.terminate(nil)}
        createMenu()
        localKeys=NSEvent.addLocalMonitorForEvents(matching:.keyDown){[weak self] event in
            guard let self=self else {return event}
            guard event.window === self.overlay || event.window === self.panel else {return event}
            if event.keyCode==53 {self.toCompanion();return nil}
            if event.modifierFlags.contains(.command),event.charactersIgnoringModifiers=="q" {NSApp.terminate(nil);return nil}
            if event.characters=="0",!event.modifierFlags.contains(.command) {self.selectTool(.spray);return nil}
            if event.characters=="8",!event.modifierFlags.contains(.command) {self.scareRoaches();return nil}
            if let s=event.characters,let n=Int(s),let tool=Tool(rawValue:n-1),!event.modifierFlags.contains(.command) {self.selectTool(tool);return nil}
            if self.world.interactive {
                if event.keyCode==36 {self.keyboardAction();return nil}
                if event.keyCode==48 {self.nextSubject();return nil}
                if event.characters==" " {self.togglePause();return nil}
                if let s=event.characters,let n=Int(s),let tool=Tool(rawValue:n-1) {self.selectTool(tool);return nil}
            }
            return event
        }
        NotificationCenter.default.addObserver(self,selector:#selector(screenChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(willSleep),name:NSWorkspace.willSleepNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(didWake),name:NSWorkspace.didWakeNotification,object:nil)
        overlay.orderFrontRegardless(); panel.orderFrontRegardless(); updateAvoid()
        lastTime=CACurrentMediaTime()
        timer=Timer(timeInterval:1.0/30.0,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        timer?.tolerance=0.003
        RunLoop.main.add(timer!,forMode:.common)
    }
    func createMenu() {
        let main = NSMenu(); let root = NSMenuItem(); main.addItem(root)
        let appMenu = NSMenu(); root.submenu=appMenu
        let show=NSMenuItem(title:"打开控制面板",action:#selector(showPanel),keyEquivalent:"0");show.target=self;appMenu.addItem(show)
        let work=NSMenuItem(title:"回到工作",action:#selector(toCompanion),keyEquivalent:"");work.target=self;appMenu.addItem(work)
        let characters=NSMenuItem(title:"角色换装与自定义图片",action:#selector(showCharacters),keyEquivalent:"k");characters.target=self;appMenu.addItem(characters)
        let credits=NSMenuItem(title:"照片与素材来源",action:#selector(showCredits),keyEquivalent:"");credits.target=self;appMenu.addItem(credits)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle:"退出桌面有点脏",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        NSApp.mainMenu=main
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        status.autosaveName="DesktopCritters.MenuBar"
        status.isVisible=true
        status.button?.image=NSImage(systemSymbolName:"ladybug.fill",accessibilityDescription:"桌面有点脏")
        status.button?.title=" 桌宠"
        status.button?.imagePosition = .imageLeading
        status.button?.toolTip="桌面有点脏 · 打开控制面板"
        status.button?.setAccessibilityLabel("桌宠 · 打开控制面板")
        let menu=NSMenu()
        let items:[(String,Selector,String)] = [("打开控制面板",#selector(showPanel),""),("角色换装与自定义图片",#selector(showCharacters),""),("收起控制面板",#selector(hidePanel),""),("今日战报",#selector(showReport),""),("惊飞蟑螂",#selector(scareRoaches),""),("竖屏取景 / 全桌面",#selector(toggleFrame),""),("生命速度 1 / 2 / 4",#selector(changeRate),""),("开一局",#selector(startRound),""),("回到工作 · 鼠标穿透",#selector(toCompanion),""),("暂停 / 继续",#selector(togglePause),""),("隐藏 / 显示全部",#selector(toggleHidden),""),("照片与素材来源",#selector(showCredits),"")]
        for (title,action,key) in items {let item=NSMenuItem(title:title,action:action,keyEquivalent:key);item.target=self;menu.addItem(item)}
        menu.addItem(.separator())
        let quit=NSMenuItem(title:"退出桌面有点脏",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); menu.addItem(quit)
        status.menu=menu
    }
    @objc func showCharacters() {
        world.release()
        if characterGallery == nil {
            characterGallery=CharacterGallery(world:world)
            characterGallery?.applied = {[weak self] in self?.arena.needsDisplay=true;self?.panelView.refresh()}
        }
        characterGallery?.rebuild();characterGallery?.showWindow(nil);characterGallery?.window?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func applyInput() {
        let interactive=world.interactive && !hidden
        overlay.ignoresMouseEvents = !interactive
        overlay.level = .floating
        overlay.backgroundColor = interactive ? NSColor.black.withAlphaComponent(0.12) : .clear
        if interactive {
            overlay.makeKeyAndOrderFront(nil); overlay.makeFirstResponder(arena)
        }
        arena.needsDisplay=true
        arena.displayIfNeeded()
        panelView.refresh()
    }
    @objc func scareRoaches() {_ = world.scareRoaches();arena.needsDisplay=true;panelView.refresh()}
    @objc func startRound() {
        hidden=false; overlay.orderFrontRegardless(); panel.orderFrontRegardless()
        world.startRound(); updateAvoid(); applyInput(); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func toCompanion() {
        world.companion(); applyInput(); arena.needsDisplay=true
    }
    func selectTool(_ tool:Tool) {
        if world.mode == .result { world.mode = .companion }
        if world.mode == .companion { world.ecologyInteractive = true }
        hidden=false; overlay.orderFrontRegardless(); panel.orderFrontRegardless()
        world.release(); world.tool=tool; world.watchedID=nil
        updateAvoid()
        world.say(["点桌面空白处，给双方加餐。","按住虫子，把它搬到你想放的地方。","拍中就会死亡，尸体留在原地。","扫把点按或拖动，扫走尸体、汁液和卵。","点选虫或卵，跟着看它的一生。Tab 可切换。","点桌面放蟑螂卵，暂停时也可以摆放。","点桌面放蚂蚁卵，暂停时也可以摆放。","","点文件夹图标，标记背后的藏卵处。再点同位置取消。","点击或拖动喷药，覆盖到的虫会死亡，尸体可清扫。"][tool.rawValue],force:true)
        applyInput(); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func toggleFrame() {
        world.release(); world.toggleFilming(); arena.needsDisplay=true; panelView.refresh()
    }
    @objc func changeRate() {
        guard world.mode != .battle else { world.say("计分竞赛固定正常速度。",force:true); return }
        world.cycleRate(); panelView.refresh(); arena.needsDisplay=true
    }
    func nextSubject() {
        let ids=world.eggs.map{$0.id}+world.bugs.map{$0.id}
        guard !ids.isEmpty else { world.watchedID=nil; return }
        if let current=world.watchedID,let i=ids.firstIndex(of:current) {world.watchedID=ids[(i+1)%ids.count]}
        else {world.watchedID=ids[0]}
        arena.needsDisplay=true
    }
    func keyboardAction() {
        guard world.interactive else {return}
        let placing=world.tool == .roachEgg || world.tool == .antEgg
        let fallback = placing ? V(x:world.tool == .roachEgg ? world.roachNest.x+100 : world.antNest.x-100,y:world.field.midY) : V(x:world.field.midX,y:world.field.midY)
        let p=placing ? (world.pointer ?? fallback) : (world.observation?.0 ?? world.pointer ?? fallback)
        if world.tool == .grab {
            if world.grabbedID != nil {world.release()}
            else {world.press(p)}
        } else {world.press(p); CharacterLibrary.shared.observe(in:world,at:p);world.release()}
        arena.needsDisplay=true
    }
    @objc func togglePause() {world.paused.toggle();world.release();panelView.refresh();arena.needsDisplay=true}
    func toggleSound() {soundEnabled.toggle();UserDefaults.standard.set(soundEnabled,forKey:"soundEnabled");panelView.soundEnabled=soundEnabled;panelView.refresh()}
    @objc func showCredits() {
        let alert=NSAlert();alert.messageText="照片与素材来源"
        let url=Bundle.main.url(forResource:"素材署名",withExtension:"txt")!
        alert.informativeText=(try? String(contentsOf:url,encoding:.utf8)) ?? "摄影：Gary Alpert · CC BY 2.5"
        alert.addButton(withTitle:"知道了");alert.runModal()
    }
    @objc func hidePanel() {panel.orderOut(nil);updateAvoid()}
    @objc func showPanel() {
        hidden=false;overlay.orderFrontRegardless();panel.orderFrontRegardless()
        // Bring the actual controls forward even if a transparent desktop window is still visible.
        updateAvoid();applyInput();panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
    }
    func applicationDockMenu(_ sender:NSApplication)->NSMenu? {
        let menu=NSMenu()
        let show=NSMenuItem(title:"打开控制面板",action:#selector(showPanel),keyEquivalent:"")
        show.target=self;menu.addItem(show)
        return menu
    }
    @objc func toggleHidden() {
        hidden.toggle()
        if hidden {world.release();overlay.ignoresMouseEvents=true;overlay.orderOut(nil);panel.orderOut(nil)}
        else {overlay.orderFrontRegardless();panel.orderFrontRegardless();updateAvoid();applyInput()}
        lastTime=CACurrentMediaTime()
    }
    func windowDidMove(_ notification:Notification) {updateAvoid()}
    func updateAvoid() {
        guard overlay != nil, panel != nil, world != nil else {return}
        if panel.isVisible {
            let r=panel.frame, f=overlay.frame
            world.avoid=CGRect(x:r.minX-f.minX,y:f.maxY-r.maxY,width:r.width,height:r.height)
        } else {world.avoid = .zero}
    }
    @objc func screenChanged() {
        let f=screen.visibleFrame;overlay.setFrame(f,display:true)
        panel.setFrameOrigin(CGPoint(x:f.maxX-346,y:max(f.minY,f.maxY-716)))
        updateAvoid();world.resize(width:f.width,height:f.height);arena.needsDisplay=true
    }
    @objc func willSleep() {world.paused=true;world.release();overlay.ignoresMouseEvents=true}
    @objc func didWake() {lastTime=CACurrentMediaTime();toCompanion()}
    @objc func tick() {
        let now=CACurrentMediaTime(),dt=now-lastTime;lastTime=now
        if now-lastSave>15 {saveEcology();lastSave=now}
        if now-lastReport>1, reportPanel?.isVisible == true {
            let scroll=reportView?.enclosingScrollView,origin=reportView?.enclosingScrollView?.contentView.bounds.origin
            reportView?.string=world.reportText
            if let point=origin {scroll?.contentView.scroll(to:point);if let clip=scroll?.contentView {scroll?.reflectScrolledClipView(clip)}}
            lastReport=now
        }
        guard !hidden else {return}
        let oldMode=world.mode
        world.update(dt)
        if oldMode != world.mode {applyInput()}
        if world.soundEvent {world.soundEvent=false;if soundEnabled {NSSound(named:"Pop")?.play()}}
        let interval:Double=world.mode == .companion ? 1.0/20.0 : 1.0/30.0
        if now-lastPaint >= interval && (!world.paused || world.interactive) {arena.needsDisplay=true;lastPaint=now}
        if now-lastUI > 0.2 {
            panelView.refresh();lastUI=now
            let mode = world.mode == .battle ? "互动中" : (world.mode == .companion ? "陪伴中" : "本局结束")
            arena.setAccessibilityLabel("互动桌面：\(mode)，\(world.foods.count)份零食，\(world.corpses.count)具尸体，\(world.eggs.count)枚卵，\(world.bugs.filter{!$0.adult}.count)只幼体，累计孵化\(world.hatchedCount)，成年\(world.maturedCount)，剩余\(Int(world.remaining))秒。关系\(world.relations.title)。冲突死亡\(world.combatDeaths)。工具\(world.tool.rawValue+1)。\(world.paused ? "暂停" : "运行")。\(world.filming ? "竖屏" : "全桌面")。生命速度\(Int(world.lifeRate))。巨型\(world.bugs.filter{$0.bulkValue>=0.78}.count)只。外敌\(world.invaders.filter{!$0.dead}.count)只。扫动\(world.sweeps.count)。汁液\(world.splats.count)摊。观察\(world.observation?.1 ?? "无")。")
        }
        // Read the global pointer position without an event tap or Accessibility permission.
        if world.interactive {
            let p=NSEvent.mouseLocation, f=overlay.frame
            let local=V(x:p.x-f.minX,y:f.maxY-p.y)
            world.pointer = f.contains(p) && !world.avoid.contains(CGPoint(x:local.x,y:local.y)) ? local : nil
            if world.grabbedID != nil, let point=world.pointer { world.drag(point) }
        }
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {showPanel();return true}
    func applicationWillTerminate(_ notification:Notification) {saveEcology();timer?.invalidate();if let keys=localKeys{NSEvent.removeMonitor(keys)}}
}

func renderPreview(to path:String) {
    let width=1440,height=960
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    let context=NSGraphicsContext(bitmapImageRep:bitmap)!
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
    let c=context.cgContext;c.translateBy(x:0,y:CGFloat(height));c.scaleBy(x:1,y:-1)
    NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:true)
    // Neutral presentation board; the installed app has a fully transparent arena.
    fillRound(CGRect(x:0,y:0,width:width,height:height),NSColor(hex:0xDFE6DA),0)
    label("桌面有点脏",62,52,42,Ink.forest,.heavy,width:740)
    label("只漏了一枚卵，桌面又有了下一代。",65,115,18,NSColor(hex:0x6F8170),.medium,width:700)
    label("MAC DESKTOP COMPANION  /  05",65,159,10,NSColor(hex:0x839182),.bold,width:700)
    // Large specimens show the same skeletons used at desktop scale.
    fillRound(CGRect(x:60,y:220,width:455,height:290),NSColor(hex:0xECE6D8),22)
    fillRound(CGRect(x:542,y:220,width:455,height:290),NSColor(hex:0xD3DFCE),22)
    c.saveGState();c.translateBy(x:250,y:319);c.rotate(by:-0.08);Creatures.roach(c,phase:1.2,scale:2.4);c.restoreGState()
    c.saveGState();c.translateBy(x:765,y:334);c.rotate(by:-0.22);Creatures.ant(c,phase:2.8,scale:2.4);c.restoreGState()
    label("01   蟑螂帮",85,426,23,Ink.forest,.bold,width:400)
    label("卵鞘孵化，小蟑螂逐步长大。",85,466,14,NSColor(hex:0x8C765E),width:400)
    label("02   蚂蚁军团",567,426,23,Ink.forest,.bold,width:400)
    label("蚁后产卵，运粮供养下一代。",567,466,14,NSColor(hex:0x6C8168),width:400)
    let world=World(width:1440,height:960,seed:42);world.startRound();world.avoid=CGRect(x:1060,y:50,width:324,height:690)
    world.roachScore=16;world.antScore=21;world.remaining=103
    world.foods=[Food(id:1,p:V(x:610,y:710),portions:18,original:18,angle:0.1)]
    world.bugs.removeAll()
    for i in 0..<13 {world.bugs.append(Bug(id:i,species:.ant,p:V(x:700+Double(i)*29,y:740+sin(Double(i)*0.5)*20),angle:Double.pi,phase:Double(i),cargo:i%3==0 ? 1 : 0))}
    world.bugs.append(Bug(id:20,species:.roach,p:V(x:402,y:674),angle:0.25,phase:0.7))
    world.bugs.append(Bug(id:21,species:.roach,p:V(x:558,y:731),angle:-0.6,phase:2))
    world.bugs.append(Bug(id:22,species:.roach,p:V(x:386,y:811),angle:-2.5,phase:3,cargo:4))
    world.bugs[0].growth = 0.12; world.bugs[2].growth = 0.55
    world.bugs[13].growth = 0.18; world.bugs[14].growth = 0.6
    world.eggs = [Egg(id:100,species:.roach,p:V(x:250,y:702),age:18,hatchTime:28,generation:2),Egg(id:101,species:.ant,p:V(x:820,y:818),age:14,hatchTime:22,generation:2)]
    world.corpses = [Corpse(bug:Bug(id:200,species:.roach,p:V(x:650,y:843),angle:0.4))]
    drawArena(world,in:c,showHint:false)
    label("卵会孵化，幼体会长大，死去会留下尸体。",65,570,24,Ink.forest,.semibold,width:900)
    label("投食 → 产卵 → 孵化 → 成长 → 下一代    /    拖鞋拍死 · 清扫尸体",65,613,13,NSColor(hex:0x778A78),width:900)
    c.saveGState();c.translateBy(x:1060,y:50)
    let card=ControlView(world:world);card.clearBeforeDrawing=false;card.draw(card.bounds)
    for view in card.subviews {c.saveGState();c.translateBy(x:view.frame.minX,y:view.frame.minY);view.draw(view.bounds);c.restoreGState()}
    c.restoreGState()
    context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
    try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
    renderIcon(to:URL(fileURLWithPath:path).deletingLastPathComponent().appendingPathComponent("AppIcon.png").path)
}

func renderIcon(to path:String) {
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    let context=NSGraphicsContext(bitmapImageRep:bitmap)!,c=context.cgContext
    NSGraphicsContext.saveGraphicsState();c.translateBy(x:0,y:1024);c.scaleBy(x:1,y:-1)
    NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:true)
    c.clear(CGRect(x:0,y:0,width:1024,height:1024))
    fillRound(CGRect(x:56,y:56,width:912,height:912),Ink.cream,210)
    fillRound(CGRect(x:102,y:102,width:820,height:820),NSColor(hex:0xDFE6D6),174)
    c.saveGState();c.translateBy(x:412,y:380);c.rotate(by:0.4);Creatures.roach(c,phase:1.3,scale:5.2);c.restoreGState()
    c.saveGState();c.translateBy(x:663,y:649);c.rotate(by:-2.35);Creatures.ant(c,phase:3.4,scale:8);c.restoreGState()
    c.saveGState();c.translateBy(x:298,y:711);Creatures.cookie(c,scale:3.2);c.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}

let arguments=CommandLine.arguments
if arguments.contains("--character-self-test") {_ = NSApplication.shared;runCharacterTests();exit(0)}
if let index=arguments.firstIndex(of:"--render-characters"),arguments.count>index+1 {_ = NSApplication.shared;renderCharacters(to:arguments[index+1]);exit(0)}
if arguments.contains("--self-test") {runWorldTests();exit(0)}
if let index=arguments.firstIndex(of:"--render-preview"),arguments.count>index+1 {_ = NSApplication.shared;renderPreview(to:arguments[index+1]);exit(0)}
if let i=arguments.firstIndex(of:"--render-feature-checks"),arguments.count>i+1 {_ = NSApplication.shared;renderFeatureChecks(to:arguments[i+1]);exit(0)}
let app=NSApplication.shared
app.setActivationPolicy(.regular)
let delegate=AppDelegate();app.delegate=delegate
app.run()
