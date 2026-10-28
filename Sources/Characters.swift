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
    var left:String? = nil
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
    private(set) var selectedID="ant"
    private(set) var leftID="roach"
    private(set) var loadNotice=""
    private var frames:[String:[NSImage]]=[:]
    var performedAt:Double = -100
    var performers=Set<Int>()
    var changed: (() -> Void)?
    static let natives:[CharacterSkin]=[
        CharacterSkin(id:"roach",name:"蟑螂",tag:"展翅惊飞 · 写实虫体",effect:"",color:0xA2784E,file:""),
        CharacterSkin(id:"ant",name:"蚂蚁",tag:"小巧搬运 · 围攻抢粮",effect:"",color:0x486852,file:""),
        CharacterSkin(id:"rat",name:"老鼠",tag:"摇尾小跑 · 争食冲撞",effect:"ram",color:0x9C8A73,file:"")]
    var all:[CharacterSkin] {Self.natives+catalog+customs}
    func selected(for side:Species)->String {side == .roach ? leftID : selectedID}
    func current(for side:Species)->CharacterSkin? {all.first{$0.id==selected(for:side)}}
    func name(for side:Species)->String {current(for:side)?.name ?? (side == .roach ? "蟑螂" : "蚂蚁")}
    func customRendering(for side:Species)->Bool {selected(for:side) != side.rawValue}
    func apply(to world:World) {
        world.leftPetID=leftID;world.rightPetID=selectedID
        world.leftPetName=name(for:.roach);world.rightPetName=name(for:.ant)
        for i in world.bugs.indices where world.petID(world.bugs[i].species) != "roach" {world.bugs[i].flight=nil}
    }
    var current:CharacterSkin? {all.first{$0.id==selectedID}}
    var displayName:String {current?.name ?? "原蚂蚁"}
    var enabled:Bool {!["roach","ant","rat"].contains(selectedID) && image(for:selectedID) != nil}
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
                selectedID=valid(config.selected) ? config.selected : "ant"
                leftID=valid(config.left ?? "roach") ? (config.left ?? "roach") : "roach"
                if selectedID != config.selected || leftID != (config.left ?? "roach") {loadNotice="部分形象文件不可用，已恢复对应队伍的默认形象。"}
            } catch {selectedID="ant";loadNotice="形象设置读取失败，原文件已保留。选择新形象可重新保存。"}
        }
    }
    private func valid(_ id:String)->Bool {all.contains{$0.id==id} && image(for:id) != nil}
    private func save(selected:String,left:String,items:[CharacterSkin]) throws {
        guard writable else{return}
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let file=folder.appendingPathComponent("appearance-v1.json")
        // Keep the previous settings as a recoverable local copy before replacing them.
        if FileManager.default.fileExists(atPath:file.path),let data=try? Data(contentsOf:file) {
            try data.write(to:folder.appendingPathComponent("appearance-previous.json"),options:.atomic)
        }
        try JSONEncoder().encode(AppearanceSave(selected:selected,left:left,customs:items)).write(to:file,options:.atomic)
    }
    func select(_ id:String,for side:Species = .ant) throws {
        guard valid(id) else {throw CharacterError.invalid("这个形象文件不可用，请重新导入。")}
        let nextLeft=side == .roach ? id : leftID,nextRight=side == .ant ? id : selectedID
        try save(selected:nextRight,left:nextLeft,items:customs)
        leftID=nextLeft;selectedID=nextRight;performedAt = -100;performers=[];changed?()
    }
    func restorePair() throws {
        try save(selected:"ant",left:"roach",items:customs)
        leftID="roach";selectedID="ant";performers=[];changed?()
    }
    func image(for id:String,pose:Int=0)->NSImage? {
        if let list=frames[id],!list.isEmpty {return list[min(list.count-1,max(0,pose))]}
        if ["roach","ant","rat"].contains(id) {
            let data=characterBitmap(width:240,height:180){c in
                c.translateBy(x:120,y:90)
                c.scaleBy(x:id=="ant" ? 4 : (id=="rat" ? 1.8 : 1.45),y:id=="ant" ? 4 : (id=="rat" ? 1.8 : 1.45))
                CharacterArt.native(c,id:id,bug:Bug(id:0,species:.roach,p:.zero))
            }
            guard let image=NSImage(data:data) else{return nil};frames[id]=[image];return image
        }
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
    @discardableResult func importImage(_ url:URL,for side:Species = .ant) throws -> CharacterSkin {
        guard customs.count<32 else {throw CharacterError.invalid("已收藏32个自定义形象，请先使用已有形象。")}
        let size=(try url.resourceValues(forKeys:[.fileSizeKey])).fileSize ?? 0
        guard size>0,size<=20*1024*1024 else {throw CharacterError.invalid("请选一张20MB以内的图片。")}
        guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],let w=properties[kCGImagePropertyPixelWidth] as? Int,let h=properties[kCGImagePropertyPixelHeight] as? Int,w>0,h>0,w<=8192,h<=8192,w*h<=32_000_000 else {throw CharacterError.invalid("图片无法读取，或尺寸过大。请使用PNG、JPEG或GIF图片。")}
        let options:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1024,kCGImageSourceCreateThumbnailWithTransform:true]
        guard let cg=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary) else {throw CharacterError.invalid("这张图片无法解码。")}
        var pixels=[UInt8](repeating:0,count:cg.width*cg.height*4)
        let visible=pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let c=CGContext(data:raw.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false}
            c.draw(cg,in:CGRect(x:0,y:0,width:cg.width,height:cg.height))
            return stride(from:3,to:raw.count,by:4).contains{raw[$0]>8}
        }
        guard visible else {throw CharacterError.invalid("图片完全透明，请选一张能看见主体的图片。")}
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
        try save(selected:side == .ant ? id : selectedID,left:side == .roach ? id : leftID,items:customs+[skin])
        customs.append(skin);if side == .ant {selectedID=id} else {leftID=id};changed?();return skin
    }
    func perform(in world:World,side:Species = .ant,ids:Set<Int>?=nil) {
        performedAt=world.clock;performers=ids ?? Set(world.bugs.filter{$0.species == side}.prefix(16).map{$0.id})
    }
    func observe(in world:World,at point:V) {
        guard world.tool == .observe,let bug=world.bugs.filter({world.bodyHit($0,point,padding:6)}).max(by:{$0.p.y<$1.p.y}) else{return}
        perform(in:world,side:bug.species,ids:[bug.id])
    }
    func performing(_ id:Int,clock:Double)->Double? {let t=(clock-performedAt)/1.6;return performers.contains(id) && t>=0 && t<1 ? t : nil}
}

enum CharacterArt {
    static func native(_ c:CGContext,id:String,bug:Bug,dead:Bool=false) {
        if id=="rat" {
            c.saveGState();c.scaleBy(x:0.52,y:0.52)
            Creatures.visitorBody(c,Invader(id:bug.id,kind:.rat,p:.zero,phase:dead ? 0 : bug.phase))
            c.restoreGState()
        } else {
            var shown=Bug(id:bug.id,species:id=="roach" ? .roach : .ant,p:bug.p,phase:bug.phase,growth:bug.growth)
            shown.bulk=bug.bulk;shown.flight=bug.flight
            Creatures.bug(c,shown,dead:dead)
        }
    }
    static func draw(_ c:CGContext,bug:Bug,clock:Double,dead:Bool=false,alpha:Double=1) {
        let library=CharacterLibrary.shared
        guard let skin=library.current(for:bug.species) else{return}
        if ["roach","ant","rat"].contains(skin.id) {
            c.saveGState();c.setAlpha(alpha);c.rotate(by:bug.angle)
            if dead {c.scaleBy(x:1.1,y:0.55)}
            native(c,id:skin.id,bug:bug,dead:dead);c.restoreGState();return
        }
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
        guard let attacker=world.bugs.first(where:{$0.id==fight.attacker}) ?? world.corpses.first(where:{$0.bug.id==fight.attacker})?.bug,
              let skin=CharacterLibrary.shared.current(for:attacker.species),!["roach","ant"].contains(skin.id) else{return false}
        let p=fight.from+(fight.to-fight.from)*0.62
        c.saveGState();c.translateBy(x:p.x,y:p.y);c.rotate(by:atan2(fight.to.y-fight.from.y,fight.to.x-fight.from.x))
        accent(c,effect:skin.effect,t:fight.age/fight.duration,size:fight.size,color:NSColor(hex:skin.color));c.restoreGState();return true
    }
}

final class CharacterTile:NSButton {
    let skin:CharacterSkin
    let side:Species
    var choose:(()->Void)?
    override var isFlipped:Bool {true}
    init(skin:CharacterSkin,side:Species,frame:CGRect) {
        self.skin=skin;self.side=side;super.init(frame:frame);isBordered=false;target=self;action=#selector(tap)
        setAccessibilityLabel((side == .roach ? "左队换成" : "右队换成")+skin.name);toolTip=skin.tag
    }
    required init?(coder:NSCoder){fatalError()}
    @objc func tap(){choose?()}
    override func draw(_ rect:NSRect) {
        let selected=CharacterLibrary.shared.selected(for:side)==skin.id
        fillRound(bounds,selected ? NSColor(hex:0xE2EEE4) : NSColor(hex:0xF0EFE7),15)
        if selected {strokeRound(bounds.insetBy(dx:1,dy:1),Ink.forest,15,1.8)}
        if let picture=CharacterLibrary.shared.image(for:skin.id) {
            let r=CGRect(x:12,y:1,width:bounds.width-24,height:88),k=min(r.width/picture.size.width,r.height/picture.size.height)
            picture.draw(in:CGRect(x:r.midX-picture.size.width*k/2,y:r.midY-picture.size.height*k/2,width:picture.size.width*k,height:picture.size.height*k),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
        }
        label(skin.name,6,88,13,Ink.forest,.semibold,width:bounds.width-12,align:.center)
        label(skin.tag,5,110,9,Ink.muted,width:bounds.width-10,align:.center)
        if selected {label("✓",bounds.width-22,9,12,Ink.forest,.bold,width:17)}
    }
}

final class CharacterGallery:NSWindowController {
    let world:World
    var applied:(()->Void)?
    private(set) var side:Species = .roach
    private let status=NSTextField(labelWithString:"")
    private let scroll=NSScrollView(),content=FlippedCharacterView()
    private var teamButtons:[ActionButton]=[]
    private var importButton:ActionButton!
    init(world:World) {
        self.world=world
        let panel=NSPanel(contentRect:CGRect(x:150,y:100,width:680,height:680),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        panel.title="选择两队宠物 · 桌面有点脏";panel.isReleasedWhenClosed=false;panel.minSize=NSSize(width:680,height:620)
        panel.level=NSWindow.Level(rawValue:NSWindow.Level.floating.rawValue+3);panel.hidesOnDeactivate=false;panel.backgroundColor=Ink.cream
        super.init(window:panel)
        let root=FlippedCharacterView(frame:CGRect(x:0,y:0,width:680,height:680));root.autoresizingMask=[.width,.height];panel.contentView=root
        let title=NSTextField(labelWithString:"今天，让谁对上谁？")
        title.font=NSFont.systemFont(ofSize:24,weight:.bold);title.textColor=Ink.forest;title.frame=CGRect(x:26,y:18,width:600,height:35);root.addSubview(title)
        let hint=NSTextField(labelWithString:"先选左队或右队，再挑角色；两边都能导入自己的图片。")
        hint.font=NSFont.systemFont(ofSize:12);hint.textColor=Ink.muted;hint.frame=CGRect(x:27,y:58,width:620,height:24);root.addSubview(hint)
        for (i,team) in [Species.roach,.ant].enumerated() {
            let button=ActionButton("",frame:CGRect(x:26+i*320,y:93,width:308,height:66)){[weak self] in self?.focus(team)}
            root.addSubview(button);teamButtons.append(button)
        }
        status.font=NSFont.systemFont(ofSize:12);status.textColor=Ink.muted;status.frame=CGRect(x:27,y:174,width:625,height:28);root.addSubview(status)
        scroll.frame=CGRect(x:24,y:211,width:632,height:316);scroll.autoresizingMask=[.width,.height];scroll.hasVerticalScroller=true;scroll.drawsBackground=false;scroll.documentView=content;root.addSubview(scroll)
        importButton=ActionButton("",frame:CGRect(x:26,y:544,width:238,height:42),style:1){[weak self] in self?.importPhoto()}
        importButton.autoresizingMask=[.minYMargin];root.addSubview(importButton)
        let original=ActionButton("蟑螂 × 蚂蚁",frame:CGRect(x:276,y:544,width:166,height:42)){[weak self] in
            guard let self=self else{return};do {try CharacterLibrary.shared.restorePair();self.apply()} catch {self.status.stringValue=error.localizedDescription}
        };original.toolTip="恢复最初的双虫组合，不重开生态";original.autoresizingMask=[.minYMargin];root.addSubview(original)
        let play=ActionButton("这一队表演一下",frame:CGRect(x:454,y:544,width:200,height:42)){[weak self] in
            guard let self=self else{return}
            guard self.world.bugs.contains(where:{$0.species==self.side}) else {self.status.stringValue="这一队还没有成员，先放卵等待孵化。";return}
            self.world.paused=false;CharacterLibrary.shared.perform(in:self.world,side:self.side);self.applied?()
            self.status.stringValue=self.world.teamName(self.side)+"登场！观察工具点它，也会回应。"
        };play.autoresizingMask=[.minYMargin];root.addSubview(play)
        let help=NSTextField(labelWithString:"PNG透明图效果最好；也支持JPEG和GIF首帧，20MB以内。\n两队可选同款。图片只保存在本机；切换角色，原生态继续。\n投食、成长、产卵、外敌和喷药共用；选蟑螂的队伍可以展翅飞行。")
        help.frame=CGRect(x:27,y:604,width:625,height:58);help.font=NSFont.systemFont(ofSize:11);help.textColor=Ink.muted;help.autoresizingMask=[.minYMargin];root.addSubview(help)
        rebuild()
    }
    required init?(coder:NSCoder){fatalError()}
    func focus(_ side:Species) {self.side=side;rebuild()}
    func rebuild() {
        content.subviews.forEach{$0.removeFromSuperview()}
        let library=CharacterLibrary.shared,skins=library.all
        content.frame=CGRect(x:0,y:0,width:620,height:max(316,ceil(Double(skins.count)/4)*140))
        for (i,skin) in skins.enumerated() {
            let card=CharacterTile(skin:skin,side:side,frame:CGRect(x:(i%4)*154,y:(i/4)*140,width:144,height:132))
            card.choose={[weak self] in self?.select(skin.id)};content.addSubview(card)
        }
        for (i,team) in [Species.roach,.ant].enumerated() {
            let b=teamButtons[i];b.title=(i==0 ? "左队 · " : "右队 · ")+String(library.name(for:team).prefix(14))
            b.subtitle=team==side ? "正在选择 · 从下方图库挑选" : "点这里，更换这一队"
            b.selected=team==side;b.setAccessibilityLabel(b.title+"，"+b.subtitle);b.needsDisplay=true
        }
        importButton.title=side == .roach ? "＋ 给左队导入图片" : "＋ 给右队导入图片";importButton.setAccessibilityLabel(importButton.title);importButton.needsDisplay=true
        status.stringValue="正在选择："+world.teamName(side)+"  ·  "+String(skins.count)+"款可选"
    }
    private func apply() {CharacterLibrary.shared.apply(to:world);rebuild();applied?()}
    func select(_ id:String) {do {try CharacterLibrary.shared.select(id,for:side);apply()} catch {status.stringValue=error.localizedDescription}}
    func importPhoto() {
        guard let window=window else{return}
        let destination=side
        let dialog=NSOpenPanel();dialog.title=destination == .roach ? "给左队选择图片" : "给右队选择图片";dialog.allowedContentTypes=[.png,.jpeg,.gif];dialog.allowsMultipleSelection=false
        dialog.beginSheetModal(for:window){[weak self] result in
            guard result == .OK,let url=dialog.url,let self=self else{return}
            do {_ = try CharacterLibrary.shared.importImage(url,for:destination);self.apply()} catch {self.status.stringValue=error.localizedDescription}
        }
    }
}
final class FlippedCharacterView:NSView {override var isFlipped:Bool {true}
    override func draw(_ dirtyRect:NSRect){Ink.cream.setFill();NSBezierPath(rect:bounds).fill()}
}
