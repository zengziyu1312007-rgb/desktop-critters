import AppKit
import ImageIO
import UniformTypeIdentifiers

struct CharacterSkin: Codable {
    let id:String
    let name:String
    let tag:String
    let effect:String
    let color:Int
    let file:String
    var custom:Bool? = nil
    var facesLeft:Bool? = nil
}
private struct AppearanceSave: Codable {
    var version=1
    var selected:String
    var customs:[CharacterSkin]
}
enum CharacterError: LocalizedError {
    case invalid(String)
    var errorDescription:String? {if case .invalid(let message)=self{return message};return nil}
}

final class CharacterLibrary {
    static var shared=CharacterLibrary()
    let folder:URL
    private let writable:Bool
    private(set) var catalog:[CharacterSkin]=[]
    private(set) var customs:[CharacterSkin]=[]
    private(set) var selectedID="nailong"
    private(set) var loadNotice=""
    private var frames:[String:[NSImage]]=[:]
    var performedAt:Double = -100
    var performers=Set<Int>()
    var changed: (() -> Void)?
    var all:[CharacterSkin] {catalog+customs}
    var current:CharacterSkin? {all.first{$0.id==selectedID}}
    var displayName:String {current?.name ?? "原蚂蚁"}
    var enabled:Bool {current != nil && image(for:selectedID) != nil}
    init(folder:URL?=nil,writable:Bool=true) {
        self.folder=folder ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("DesktopCritters")
        self.writable=writable
        if let url=Bundle.main.url(forResource:"catalog",withExtension:"json",subdirectory:"Characters"),let data=try? Data(contentsOf:url),let items=try? JSONDecoder().decode([CharacterSkin].self,from:data) {catalog=items}
        let url=self.folder.appendingPathComponent("appearance-v1.json")
        if FileManager.default.fileExists(atPath:url.path) {
            do {
                let config=try JSONDecoder().decode(AppearanceSave.self,from:Data(contentsOf:url))
                guard config.version==1 else {throw CharacterError.invalid("形象设置来自其他版本。")}
                var seen=Set(catalog.map{$0.id})
                customs=Array(config.customs.filter{item in
                    guard item.custom==true,item.id.hasPrefix("custom-"),!seen.contains(item.id),item.file==item.id+".png",!item.file.contains("/"),!item.file.contains("\\"),item.file.count<90 else{return false}
                    seen.insert(item.id);return true
                }.prefix(32))
                selectedID=config.selected=="ant" || all.contains{$0.id==config.selected} ? config.selected : "ant"
                if selectedID != "ant" && image(for:selectedID)==nil {selectedID="ant";loadNotice="上次形象文件不可用，已显示原蚂蚁。"}
            } catch {selectedID="ant";loadNotice="形象设置读取失败，原文件已保留。选择新形象可重新保存。"}
        }
    }
    private func save(selected:String,items:[CharacterSkin]) throws {
        guard writable else{return}
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let file=folder.appendingPathComponent("appearance-v1.json")
        // Keep the previous settings as a recoverable local copy before replacing them.
        if FileManager.default.fileExists(atPath:file.path),let data=try? Data(contentsOf:file) {
            try data.write(to:folder.appendingPathComponent("appearance-previous.json"),options:.atomic)
        }
        try JSONEncoder().encode(AppearanceSave(selected:selected,customs:items)).write(to:file,options:.atomic)
    }
    func select(_ id:String) throws {
        guard id=="ant" || (all.contains{$0.id==id} && image(for:id) != nil) else {throw CharacterError.invalid("这个形象文件不可用，请重新导入。")}
        try save(selected:id,items:customs)
        selectedID=id;performedAt = -100;performers=[];changed?()
    }
    func image(for id:String,pose:Int=0)->NSImage? {
        if let list=frames[id],!list.isEmpty {return list[min(list.count-1,max(0,pose))]}
        guard let skin=all.first(where:{$0.id==id}) else{return nil}
        let url:URL?
        if skin.custom==true {url=folder.appendingPathComponent("CustomCharacters").appendingPathComponent(skin.file)}
        else {url=Bundle.main.url(forResource:skin.file,withExtension:nil,subdirectory:"Characters")}
        guard let u=url,let source=CGImageSourceCreateWithURL(u as CFURL,nil),let cg=CGImageSourceCreateImageAtIndex(source,0,nil),cg.width>0,cg.height>0 else{return nil}
        if skin.custom==true {frames[id]=[NSImage(cgImage:cg,size:NSSize(width:cg.width,height:cg.height))]}
        else {
            let w=cg.width/2,h=cg.height/2
            frames[id]=(0..<4).compactMap {i in
                guard let part=cg.cropping(to:CGRect(x:(i%2)*w,y:(i/2)*h,width:w,height:h)) else{return nil}
                return NSImage(cgImage:part,size:NSSize(width:w,height:h))
            }
        }
        return frames[id]?.first.flatMap{_ in image(for:id,pose:pose)}
    }
    @discardableResult func importImage(_ url:URL) throws -> CharacterSkin {
        guard customs.count<32 else {throw CharacterError.invalid("已收藏32个自定义形象，请先使用已有形象。")}
        let size=(try url.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0
        guard size>0,size<=20*1024*1024 else {throw CharacterError.invalid("请选一张20MB以内的图片。")}
        guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],let w=properties[kCGImagePropertyPixelWidth] as? Int,let h=properties[kCGImagePropertyPixelHeight] as? Int,w>0,h>0,w<=8192,h<=8192,w*h<=32_000_000 else {throw CharacterError.invalid("图片无法读取，或尺寸过大。请使用PNG、JPEG或GIF图片。")}
        let options:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1024,kCGImageSourceCreateThumbnailWithTransform:true]
        guard let cg=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else {throw CharacterError.invalid("这张图片无法解码。")}
        let id="custom-"+UUID().uuidString.lowercased(),target=folder.appendingPathComponent("CustomCharacters")
        try FileManager.default.createDirectory(at:target,withIntermediateDirectories:true)
        let png=target.appendingPathComponent(id+".png")
        guard let output=CGImageDestinationCreateWithURL(png as CFURL,UTType.png.identifier as CFString,1,nil) else {throw CharacterError.invalid("图片保存失败。")}
        CGImageDestinationAddImage(output,cg,nil)
        guard CGImageDestinationFinalize(output) else {throw CharacterError.invalid("图片保存失败。")}
        let originals=target.appendingPathComponent("Originals")
        try FileManager.default.createDirectory(at:originals,withIntermediateDirectories:true)
        let ext=["png","jpg","jpeg","gif"].contains(url.pathExtension.lowercased()) ? url.pathExtension.lowercased() : "image"
        try FileManager.default.copyItem(at:url,to:originals.appendingPathComponent(id+"."+ext))
        let name=String(url.deletingPathExtension().lastPathComponent.prefix(20))
        let skin=CharacterSkin(id:id,name:name.isEmpty ? "我的形象" : name,tag:"我的形象 · 弹跳与星光",effect:"stars",color:0x8DCBB8,file:id+".png",custom:true)
        try save(selected:id,items:customs+[skin])
        customs.append(skin);selectedID=id;changed?();return skin
    }
    func perform(in world:World,ids:Set<Int>?=nil) {
        guard enabled else{return}
        performedAt=world.clock;performers=ids ?? Set(world.bugs.filter{$0.species == .ant}.prefix(16).map{$0.id})
    }
    func observe(in world:World,at point:V) {
        guard enabled,world.tool == .observe,let bug=world.bugs.filter({$0.species == .ant && world.bodyHit($0,point,padding:6)}).max(by:{$0.p.y<$1.p.y}) else{return}
        perform(in:world,ids:[bug.id])
    }
    func performing(_ id:Int,clock:Double)->Double? {let t=(clock-performedAt)/1.6;return performers.contains(id) && t>=0 && t<1 ? t : nil}
}

enum CharacterArt {
    static func draw(_ c:CGContext,bug:Bug,clock:Double,dead:Bool=false,alpha:Double=1) {
        let library=CharacterLibrary.shared
        guard let skin=library.current else{return}
        let playful=library.performing(bug.id,clock:clock)
        let eating=(bug.bitePulse ?? 0)>0
        let walking=bug.speed>6
        let pose=dead ? 0 : (bug.fightTime>0 || playful != nil ? 3 : (eating ? 2 : (walking && sin(bug.phase)>0 ? 1 : 0)))
        guard let picture=library.image(for:skin.id,pose:pose) else{return}
        c.saveGState();c.setAlpha(alpha)
        if dead {c.rotate(by:0.26);c.scaleBy(x:1.12,y:0.56)}
        else {
            let bounce=playful.map{abs(sin($0*Double.pi*4))*5} ?? (walking ? abs(sin(bug.phase))*1.4 : 0)
            c.translateBy(x:0,y:-bounce)
            let bite=eating ? sin((bug.bitePulse ?? 0)/0.55*Double.pi)*0.12 : 0
            let breath=sin(clock*2+Double(bug.id))*0.016
            c.scaleBy(x:1+bite+breath,y:1-bite*0.55+breath)
            c.rotate(by:playful != nil ? sin(clock*14+Double(bug.id))*0.13 : (walking ? sin(bug.phase)*0.045 : 0))
        }
        c.scaleBy(x:(cos(bug.angle)<0) != (skin.facesLeft ?? false) ? -1 : 1,y:1)
        let h:Double=36,w=h*picture.size.width/picture.size.height
        let fit=min(1,36/w)
        picture.draw(in:CGRect(x:-w*fit/2,y:-h*fit/2,width:w*fit,height:h*fit),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high.rawValue])
        if dead {
            for n in 0..<3 {star(c,at:CGPoint(x:Double(n-1)*7,y:-15-Double(n%2)*3),radius:1.6,color:NSColor(hex:skin.color,alpha:0.65))}
        } else if playful != nil {
            accent(c,effect:skin.effect,t:playful!,size:0.52,color:NSColor(hex:skin.color))
        }
        c.restoreGState()
    }
    static func star(_ c:CGContext,at p:CGPoint,radius:Double,color:NSColor) {
        let path=CGMutablePath()
        for n in 0..<10 {let a=Double(n)*Double.pi/5-Double.pi/2,r=radius*(n%2==0 ? 1 : 0.42),v=CGPoint(x:p.x+cos(a)*r,y:p.y+sin(a)*r);if n==0 {path.move(to:v)} else {path.addLine(to:v)}}
        path.closeSubpath();c.addPath(path);c.setFillColor(color.cgColor);c.fillPath()
    }
    static func accent(_ c:CGContext,effect:String,t:Double,size:Double=1,color:NSColor) {
        c.saveGState();c.scaleBy(x:size,y:size);c.setAlpha(max(0,1-t)*0.9)
        switch effect {
        case "beam":
            line(c,[CGPoint(x:-20,y:0),CGPoint(x:32+t*24,y:0)],color.withAlphaComponent(0.35),8*(1-t)+1)
            line(c,[CGPoint(x:-20,y:0),CGPoint(x:32+t*24,y:0)],.white,1.5)
            c.setStrokeColor(color.cgColor);c.setLineWidth(1);c.strokeEllipse(in:CGRect(x:10+t*10,y:-13-t*12,width:10,height:26+t*24))
        case "electric":
            for side in [-1.0,1.0] {line(c,[CGPoint(x:-20,y:side*7),CGPoint(x:-5,y:side*14),CGPoint(x:3,y:side*3),CGPoint(x:18,y:side*13),CGPoint(x:34+t*15,y:side*2)],color,2.1)}
        case "bubbles":
            for n in 0..<6 {let a=Double(n)*2.4,r=3+Double(n%3);c.setStrokeColor(color.withAlphaComponent(0.8).cgColor);c.setLineWidth(1);c.strokeEllipse(in:CGRect(x:cos(a)*(12+t*25)-r,y:sin(a)*(12+t*25)-t*15-r,width:r*2,height:r*2))}
        case "calm":
            for n in 0..<3 {let r=10+Double(n)*9+t*12;c.setStrokeColor(color.withAlphaComponent(0.55).cgColor);c.setLineWidth(1);c.strokeEllipse(in:CGRect(x:-r,y:8-r*0.3,width:r*2,height:r*0.6))}
        case "claw":
            for n in -1...1 {let y=Double(n)*7;line(c,[CGPoint(x:-15,y:y-12),CGPoint(x:5,y:y),CGPoint(x:18,y:y+5)],color,1.7)}
        case "ram":
            for n in -1...1 {let y=Double(n)*9;line(c,[CGPoint(x:-27-t*15,y:y),CGPoint(x:0,y:y)],color,2)}
            c.setStrokeColor(color.cgColor);c.setLineWidth(2);c.strokeEllipse(in:CGRect(x:3+t*12,y:-17,width:15,height:34))
        case "bounce":
            let r=13+t*26;c.setStrokeColor(color.cgColor);c.setLineWidth(2*(1-t)+0.5);c.strokeEllipse(in:CGRect(x:-r,y:-r*0.65,width:r*2,height:r*1.3))
            for n in 0..<4 {let a=Double(n)*Double.pi/2;star(c,at:CGPoint(x:cos(a)*r,y:sin(a)*r),radius:3,color:color)}
        default:
            for n in 0..<6 {let a=Double(n)*2.4,r=11+t*25;star(c,at:CGPoint(x:cos(a)*r,y:sin(a)*r-t*8),radius:2+Double(n%3),color:color)}
        }
        c.restoreGState()
    }
    static func fight(_ c:CGContext,_ fight:FightEffect,world:World)->Bool {
        guard CharacterLibrary.shared.enabled,let skin=CharacterLibrary.shared.current,
              (world.bugs.first{$0.id==fight.attacker} ?? world.corpses.first{$0.bug.id==fight.attacker}?.bug)?.species == .ant else{return false}
        let p=fight.from+(fight.to-fight.from)*0.62
        c.saveGState();c.translateBy(x:p.x,y:p.y);c.rotate(by:atan2(fight.to.y-fight.from.y,fight.to.x-fight.from.x))
        accent(c,effect:skin.effect,t:fight.age/fight.duration,size:fight.size,color:NSColor(hex:skin.color));c.restoreGState();return true
    }
}

final class CharacterTile:NSButton {
    let skin:CharacterSkin
    var choose:(()->Void)?
    override var isFlipped:Bool {true}
    init(skin:CharacterSkin,frame:CGRect) {
        self.skin=skin;super.init(frame:frame);isBordered=false;target=self;action=#selector(tap)
        setAccessibilityLabel("换成"+skin.name);toolTip=skin.tag
    }
    required init?(coder:NSCoder){fatalError()}
    @objc func tap(){choose?()}
    override func draw(_ rect:NSRect) {
        let selected=CharacterLibrary.shared.selectedID==skin.id
        fillRound(bounds,selected ? NSColor(hex:0xE2EEE4) : NSColor(hex:0xF0EFE7),15)
        if selected {strokeRound(bounds.insetBy(dx:1,dy:1),Ink.forest,15,1.8)}
        if let picture=CharacterLibrary.shared.image(for:skin.id) {
            let r=CGRect(x:12,y:1,width:bounds.width-24,height:96)
            let k=min(r.width/picture.size.width,r.height/picture.size.height)
            picture.draw(in:CGRect(x:r.midX-picture.size.width*k/2,y:r.midY-picture.size.height*k/2,width:picture.size.width*k,height:picture.size.height*k),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
        }
        label(skin.name,6,94,13,Ink.forest,.semibold,width:bounds.width-12,align:.center)
        label(skin.tag,5,116,9,Ink.muted,width:bounds.width-10,align:.center)
        if selected {label("✓",bounds.width-22,9,12,Ink.forest,.bold,width:17)}
    }
}

final class CharacterGallery:NSWindowController {
    let world:World
    var applied:(()->Void)?
    private let status=NSTextField(labelWithString:"")
    private let scroll=NSScrollView()
    private let content=FlippedCharacterView()
    init(world:World) {
        self.world=world
        let panel=NSPanel(contentRect:CGRect(x:150,y:130,width:680,height:590),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        panel.title="角色换装 · 桌面有点脏";panel.isReleasedWhenClosed=false;panel.minSize=NSSize(width:680,height:590)
        panel.level=NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue+3);panel.hidesOnDeactivate=false
        panel.backgroundColor=Ink.cream
        super.init(window:panel)
        let root=FlippedCharacterView(frame:CGRect(x:0,y:0,width:680,height:590));root.autoresizingMask=[.width,.height];panel.contentView=root
        let title=NSTextField(labelWithString:"给蚂蚁阵营换个主角")
        title.font=NSFont.systemFont(ofSize:24,weight:.bold);title.textColor=Ink.forest;title.frame=CGRect(x:26,y:20,width:450,height:35);root.addSubview(title)
        status.font=NSFont.systemFont(ofSize:12);status.textColor=Ink.muted;status.frame=CGRect(x:27,y:62,width:620,height:28);root.addSubview(status)
        scroll.frame=CGRect(x:24,y:102,width:632,height:342);scroll.autoresizingMask=[.width,.height];scroll.hasVerticalScroller=true;scroll.drawsBackground=false;scroll.documentView=content;root.addSubview(scroll)
        let pick=ActionButton("＋ 导入自己的图片",frame:CGRect(x:26,y:460,width:238,height:42),style:1){[weak self] in self?.importPhoto()}
        pick.autoresizingMask=[.minYMargin];root.addSubview(pick)
        let original=ActionButton("恢复原蚂蚁",frame:CGRect(x:276,y:460,width:166,height:42)){[weak self] in self?.select("ant")}
        original.autoresizingMask=[.minYMargin];root.addSubview(original)
        let play=ActionButton("表演一下",frame:CGRect(x:454,y:460,width:200,height:42)){[weak self] in
            guard let self=self else{return};self.world.paused=false;CharacterLibrary.shared.perform(in:self.world);self.applied?();self.status.stringValue="看桌面："+CharacterLibrary.shared.displayName+"登场！观察工具点它，也会回应。"
        };play.autoresizingMask=[.minYMargin];root.addSubview(play)
        let help=NSTextField(labelWithString:"PNG透明图效果最好；也支持JPEG和GIF首帧，20MB以内。\n图片保存在这台电脑。切换立即生效，当前生态继续成长。")
        help.frame=CGRect(x:27,y:520,width:625,height:42);help.font=NSFont.systemFont(ofSize:11);help.textColor=Ink.muted;help.autoresizingMask=[.minYMargin];root.addSubview(help)
        rebuild()
    }
    required init?(coder:NSCoder){fatalError()}
    func rebuild() {
        content.subviews.forEach{$0.removeFromSuperview()}
        let skins=CharacterLibrary.shared.all
        content.frame=CGRect(x:0,y:0,width:620,height:max(336,ceil(Double(skins.count)/4)*150))
        for (i,skin) in skins.enumerated() {
            let card=CharacterTile(skin:skin,frame:CGRect(x:(i%4)*154,y:(i/4)*150,width:144,height:140))
            card.choose={[weak self] in self?.select(skin.id)};content.addSubview(card)
        }
        status.stringValue="当前："+CharacterLibrary.shared.displayName+"  ·  点一个形象，整支蚂蚁队伍一起换装。"
    }
    func select(_ id:String) {
        do {try CharacterLibrary.shared.select(id);world.antAvatarEnabled=CharacterLibrary.shared.enabled;rebuild();applied?()}
        catch {status.stringValue=error.localizedDescription}
    }
    func importPhoto() {
        guard let window=window else{return}
        let dialog=NSOpenPanel();dialog.title="选择你的桌宠形象";dialog.allowedContentTypes=[.png,.jpeg,.gif];dialog.allowsMultipleSelection=false
        dialog.beginSheetModal(for:window){[weak self] result in
            guard result == .OK,let url=dialog.url,let self=self else{return}
            do {_ = try CharacterLibrary.shared.importImage(url);self.world.antAvatarEnabled=CharacterLibrary.shared.enabled;self.rebuild();self.applied?()}
            catch {self.status.stringValue=error.localizedDescription}
        }
    }
}
final class FlippedCharacterView:NSView {override var isFlipped:Bool {true}}
