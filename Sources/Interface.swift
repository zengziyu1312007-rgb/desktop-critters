import AppKit

final class ActionButton: NSButton {
    var perform: (() -> Void)?
    var style: Int = 0
    var selected = false
    var hovered = false
    var subtitle = ""
    override var isFlipped: Bool { true }
    init(_ title: String,frame: CGRect,style: Int = 0,action: @escaping () -> Void) {
        super.init(frame:frame); self.title=title; self.style=style; perform=action
        isBordered=false; target=self; self.action = #selector(invoke)
        setAccessibilityLabel(title); setAccessibilityRole(.button)
    }
    required init?(coder:NSCoder) { fatalError() }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    @objc func invoke() { perform?() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); trackingAreas.forEach{removeTrackingArea($0)}
        addTrackingArea(NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseEnteredAndExited],owner:self,userInfo:nil))
    }
    override func mouseEntered(with event:NSEvent) { hovered=true; needsDisplay=true }
    override func mouseExited(with event:NSEvent) { hovered=false; needsDisplay=true }
    override func draw(_ dirtyRect:NSRect) {
        let bg: NSColor
        if style == 1 { bg = hovered ? NSColor(hex:0x365647) : Ink.forest }
        else if style == 2 { bg = hovered ? NSColor(hex:0xF0DAC7) : NSColor(hex:0xF0E7D9) }
        else { bg = selected ? Ink.forest : (hovered ? NSColor(hex:0xE8E8DE) : NSColor(hex:0xEEEDE5)) }
        fillRound(bounds,bg,style == 1 ? 13 : 11)
        let foreground: NSColor = style == 1 || selected ? Ink.cream : Ink.forest
        if !isEnabled { NSColor.white.withAlphaComponent(0.55).setFill(); NSBezierPath(rect:bounds).fill() }
        if subtitle.isEmpty {
            label(title,2,(bounds.height-21)/2,style==1 ? 14 : 12,foreground,.semibold,width:bounds.width-4,align:.center)
        } else {
            label(title,2,11,13,foreground,.semibold,width:bounds.width-4,align:.center)
            label(subtitle,2,32,10,foreground.withAlphaComponent(0.58),.medium,width:bounds.width-4,align:.center)
        }
    }
}

final class ControlView: NSView {
    let world: World
    var onStart:(() -> Void)?; var onCompanion:(() -> Void)?; var onPause:(() -> Void)?
    var onHide:(() -> Void)?; var onTool:((Tool)->Void)?; var onSound:(()->Void)?; var onQuit:(()->Void)?
    var onFrame:(()->Void)?; var onRate:(()->Void)?; var onReport:(()->Void)?
    var onCharacters:((Species)->Void)?;var characterButtons:[ActionButton]=[]
    var snacks:[ActionButton]=[]
    var frameButton:ActionButton!; var rateButton:ActionButton!
    var soundEnabled = false
    var clearBeforeDrawing = true
    var startButton: ActionButton!
    var pauseButton: ActionButton!
    var modeButton: ActionButton!
    var soundButton: ActionButton!
    var tools:[ActionButton] = []
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    init(world: World) {
        self.world=world; super.init(frame:CGRect(x:0,y:0,width:324,height:734))
        let hide = ActionButton("−",frame:CGRect(x:264,y:18,width:36,height:28)){[weak self] in self?.onHide?()}; hide.toolTip="收起面板；点顶部「桌宠」或 Dock 图标重新打开";hide.setAccessibilityLabel("收起控制面板");addSubview(hide)
        startButton = ActionButton("开一局  ·  2 分 30 秒",frame:CGRect(x:22,y:278,width:280,height:46),style:1){[weak self] in self?.onStart?()}; addSubview(startButton)
        let names = ["丢饼干","搬个家","拍死","扫把"]
        let subtitles = ["投食 · 1","拖动 · 2","拖鞋 · 3","清扫 · 4"]
        for i in 0..<4 {
            let b = ActionButton(names[i],frame:CGRect(x:22+i*58,y:389,width:52,height:58)){[weak self] in self?.onTool?(Tool(rawValue:i)!)}
            b.subtitle=subtitles[i]; b.toolTip=subtitles[i]; addSubview(b); tools.append(b)
        }
        let poison=ActionButton("杀虫剂",frame:CGRect(x:254,y:389,width:48,height:58)){[weak self] in self?.onTool?(.spray)};poison.subtitle="喷药 · 0";addSubview(poison)
        modeButton = ActionButton("回到工作",frame:CGRect(x:22,y:463,width:133,height:33)){[weak self] in self?.onCompanion?()}; addSubview(modeButton)
        pauseButton = ActionButton("暂停",frame:CGRect(x:169,y:463,width:133,height:33)){[weak self] in self?.onPause?()}; addSubview(pauseButton)
        soundButton = ActionButton("音效：关",frame:CGRect(x:22,y:542,width:90,height:25)){[weak self] in self?.onSound?()}; addSubview(soundButton)
        let quit = ActionButton("退出",frame:CGRect(x:246,y:542,width:56,height:25)){[weak self] in self?.onQuit?()}; addSubview(quit)
        let observe=ActionButton("观察 · 5",frame:CGRect(x:22,y:582,width:88,height:36)){[weak self] in self?.onTool?(.observe)}
        addSubview(observe); tools.append(observe)
        frameButton=ActionButton("竖屏取景",frame:CGRect(x:118,y:582,width:88,height:36)){[weak self] in self?.onFrame?()}
        addSubview(frameButton)
        rateButton=ActionButton("生命 ×1",frame:CGRect(x:214,y:582,width:88,height:36)){[weak self] in self?.onRate?()}
        addSubview(rateButton)
        let roachEgg=ActionButton("放左队卵 · 6",frame:CGRect(x:22,y:656,width:133,height:38)){[weak self] in self?.onTool?(.roachEgg)}
        let antEgg=ActionButton("放右队卵 · 7",frame:CGRect(x:169,y:656,width:133,height:38)){[weak self] in self?.onTool?(.antEgg)}
        addSubview(roachEgg); addSubview(antEgg); tools.append(roachEgg); tools.append(antEgg)
        for snack in Snack.allCases {
            let b=ActionButton(snack.title,frame:CGRect(x:22+(snack.rawValue%3)*96,y:326+(snack.rawValue/3)*30,width:88,height:26)){[weak self] in
                self?.world.selectedSnack=snack;self?.onTool?(.food);self?.refresh()
            };addSubview(b);snacks.append(b)
        }
        let report=ActionButton("今日战报",frame:CGRect(x:118,y:542,width:122,height:25)){[weak self] in self?.onReport?()};addSubview(report)
        let fly=ActionButton("惊飞蟑螂 · 8",frame:CGRect(x:22,y:624,width:133,height:26)){[weak self] in
            _ = self?.world.scareRoaches();self?.refresh()
        };addSubview(fly)
        let shelter=ActionButton("藏卵处 · 9",frame:CGRect(x:169,y:624,width:133,height:26)){[weak self] in self?.onTool?(.shelter)};shelter.toolTip="点桌面文件夹图标，指定藏卵处；再点同位置取消";addSubview(shelter)
        let visitor=NSPopUpButton(frame:CGRect(x:22,y:700,width:180,height:28),pullsDown:false)
        visitor.addItems(withTitles:InvaderKind.allCases.map{$0.title});visitor.setAccessibilityLabel("选择外来物种");addSubview(visitor)
        let summon=ActionButton("引来外敌",frame:CGRect(x:210,y:701,width:92,height:26)){[weak self,weak visitor] in
            guard let self=self,let index=visitor?.indexOfSelectedItem,index>=0 else {return}
            _ = self.world.summonInvader(InvaderKind.allCases[index]);self.refresh()
        };addSubview(summon)
        for (i,team) in [Species.roach,.ant].enumerated() {
            let b=ActionButton("选宠物",frame:CGRect(x:30+i*147,y:164,width:116,height:23)){[weak self] in self?.onCharacters?(team)}
            addSubview(b);characterButtons.append(b)
        }
        refresh()
    }
    required init?(coder:NSCoder) { fatalError() }
    func refresh() {
        for (i,team) in [Species.roach,.ant].enumerated() {
            let b=characterButtons[i];b.title=(i==0 ? "左 · " : "右 · ")+String(CharacterLibrary.shared.name(for:team).prefix(6))+" ›"
            b.setAccessibilityLabel((i==0 ? "选择左队宠物，当前" : "选择右队宠物，当前")+CharacterLibrary.shared.name(for:team));b.needsDisplay=true
        }
        startButton.title = world.mode == .battle ? "进行中  ·  点击重新开局" : (world.mode == .result ? "再来一局" : "开一局  ·  2 分 30 秒")
        for (i,b) in snacks.enumerated() {b.selected=i==world.selectedSnack.rawValue;b.needsDisplay=true}
        tools[0].title="投食"
        frameButton.title = world.filming ? "全桌面" : "竖屏取景"
        rateButton.title = world.mode == .battle ? "竞赛 ×1" : "生命 ×\(Int(world.lifeRate))"
        frameButton.needsDisplay=true; rateButton.needsDisplay=true
        pauseButton.title = world.paused ? "继续" : "暂停"
        modeButton.title = world.mode == .companion && !world.interactive ? "陪伴中 · 不挡鼠标" : "回到工作  ·  Esc"
        soundButton.title = soundEnabled ? "音效：开" : "音效：关"
        for (i,b) in tools.enumerated() { b.selected = world.interactive && world.tool.rawValue==i; b.needsDisplay=true }
        [startButton,pauseButton,modeButton,soundButton].forEach{$0?.needsDisplay=true}
        needsDisplay=true
    }
    override func mouseDown(with event:NSEvent) {
        let p = convert(event.locationInWindow,from:nil)
        if p.y<106 { window?.performDrag(with:event) }
    }
    override func draw(_ dirtyRect:NSRect) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        if clearBeforeDrawing {c.clear(bounds)}
        fillRound(bounds,Ink.cream,23)
        strokeRound(bounds.insetBy(dx:0.5,dy:0.5),NSColor(hex:0xFFFFFF,alpha:0.85),23)
        label("LITTLE TROUBLE CLUB",22,22,9,Ink.muted,.bold,width:236)
        label("桌面有点脏",22,44,29,Ink.forest,.heavy,width:268)
        label("喂一口，长一截。小心养成桌面巨兽。",23,83,12,NSColor(hex:0x65746A),.medium,width:270)
        // Two camps sit on contrasting, quiet fields. Illustrations match the actual pets.
        fillRound(CGRect(x:22,y:116,width:133,height:121),NSColor(hex:0xF0E0CE),15)
        fillRound(CGRect(x:169,y:116,width:133,height:121),NSColor(hex:0xDFE9DD),15)
        for (i,team) in [Species.roach,.ant].enumerated() {
            if let image=CharacterLibrary.shared.image(for:CharacterLibrary.shared.selected(for:team)) {
                let k=min(115/image.size.width,48/image.size.height)
                image.draw(in:CGRect(x:Double(88+i*147)-image.size.width*k/2,y:118,width:image.size.width*k,height:image.size.height*k),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
            }
        }
        label("\(world.roachFood)",33,184,30,Ink.forest,.bold,width:70)
        label("\(world.antFood)",180,184,30,Ink.forest,.bold,width:70)
        label("口粮",111,204,10,NSColor(hex:0x98755A),width:35)
        label("口粮",258,204,10,NSColor(hex:0x758971),width:35)
        label(world.lifeSummary(.roach),33,222,9,NSColor(hex:0x805538),.medium,width:119)
        label(world.lifeSummary(.ant),180,222,9,NSColor(hex:0x486852),.medium,width:119)
        let status = world.mode == .companion ? (world.interactive ? "●  生态互动中" : "●  自主成长中") : (world.mode == .result ? "●  本局结束" : (world.paused ? "●  已暂停" : "●  抢饭进行中"))
        label(status,23,250,11,Ink.forest,.semibold,width:190)
        let time = world.mode == .companion ? (world.interactive ? "Esc 穿透" : "鼠标可穿透") : String(format:"%02d:%02d",Int(ceil(world.remaining))/60,Int(ceil(world.remaining))%60)
        label(time,208,247,world.mode == .companion ? 11 : 18,Ink.forest,.semibold,width:93,align:.right)

        let notice: String
        if world.mode == .result { notice = world.resultTitle }
        else if world.notice.time>0 { notice = world.notice.text }
        else if let detail=world.observation?.1 { notice=detail }
        else if world.mode == .companion { notice = "点虫喂食，巨型大餐能养出泰坦。" }
        else { notice = "搬粮供养下一代。拍死留尸，按 4 清扫。" }
        label(notice,23,510,11,NSColor(hex:0x64776A),.medium,width:280)

    }
}

final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
final class ControlPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
