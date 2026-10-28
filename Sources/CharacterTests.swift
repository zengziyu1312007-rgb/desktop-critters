import AppKit

func runCharacterTests() {
    var count=0
    func check(_ condition:@autoclosure()->Bool,_ name:String) {count+=1;if !condition(){print("FAIL: "+name);exit(1)};print("PASS: "+name)}
    let base=FileManager.default.temporaryDirectory.appendingPathComponent("DesktopCritters-CharacterTests-"+UUID().uuidString)
    let library=CharacterLibrary(folder:base)
    CharacterLibrary.shared=library
    check(library.catalog.count==8,"eight built-in characters")
    check(Set(library.catalog.map{$0.id}).count==8,"unique skin ids")
    for skin in library.catalog {
        for pose in 0..<4 {check(library.image(for:skin.id,pose:pose) != nil,"decode \(skin.id) pose \(pose)")}
        try! library.select(skin.id)
        check(CharacterLibrary(folder:base).selectedID==skin.id,"persist selection \(skin.id)")
    }
    let world=World(width:1440,height:900,seed:24)
    func canonical()->Data {let object=try! JSONSerialization.jsonObject(with:world.saveData());return try! JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])}
    let before=canonical()
    try! library.select("nailong");world.antAvatarEnabled=library.enabled
    check(canonical()==before,"switching appearance does not change ecology or random state")
    let ant=Bug(id:89,species:.ant,p:V(x:300,y:300),angle:Double.pi/2)
    check(world.bodyHit(ant,V(x:300,y:284)),"upright character head is clickable regardless of travel angle")
    check(!world.bodyHit(ant,V(x:340,y:300)),"character hit target does not cover empty distant pixels")
    let safe=world.safeBug(V(x:-100,y:-100),ant)
    check(safe.x>=world.field.minX+18 && safe.y>=world.field.minY+20,"upright skin stays within desktop edges")
    library.perform(in:world,ids:[89])
    check(library.performing(89,clock:world.clock+0.1) != nil && library.performing(90,clock:world.clock+0.1)==nil,"click response is limited to selected actors")
    check(library.performing(89,clock:world.clock+2)==nil,"character performance expires")
    check(canonical()==before,"performing does not inflict damage or create population")
    try! library.select("ant");world.antAvatarEnabled=false
    check(!library.enabled && CharacterLibrary(folder:base).selectedID=="ant","restore original ant and persist")
    do {try library.select("missing");check(false,"invalid selection rejects")}catch{check(library.selectedID=="ant","invalid selection preserves choice")}
    let png=Bundle.main.url(forResource:"nailong",withExtension:"png",subdirectory:"Characters")!
    let custom=try! library.importImage(png)
    check(custom.custom==true && library.selectedID==custom.id,"custom image imports and selects")
    let image=library.image(for:custom.id)!
    check(image.size.width<=1024 && image.size.height<=1024,"import normalizes oversized sprites")
    check(FileManager.default.fileExists(atPath:base.appendingPathComponent("CustomCharacters/Originals/"+custom.id+".png").path),"original import retained separately")
    let loaded=CharacterLibrary(folder:base)
    check(loaded.selectedID==custom.id && loaded.image(for:custom.id) != nil,"custom image survives reopening")
    let bad=base.appendingPathComponent("invalid.png");try! Data("invalid".utf8).write(to:bad)
    do {_ = try library.importImage(bad);check(false,"invalid image rejects")}catch{check(library.selectedID==custom.id,"invalid image does not erase working selection")}
    let invisible=base.appendingPathComponent("invisible.png")
    try! characterBitmap(width:16,height:16){$0.clear(CGRect(x:0,y:0,width:16,height:16))}.write(to:invisible)
    do {_ = try library.importImage(invisible);check(false,"transparent image rejects")}catch{check(library.selectedID==custom.id,"transparent image preserves choice")}
    let config=base.appendingPathComponent("appearance-v1.json")
    let malicious="{\"version\":1,\"selected\":\"custom-bad\",\"customs\":[{\"id\":\"custom-bad\",\"name\":\"bad\",\"tag\":\"\",\"effect\":\"stars\",\"color\":0,\"file\":\"../outside.png\",\"custom\":true}]}"
    try! Data(malicious.utf8).write(to:config)
    let sanitized=CharacterLibrary(folder:base)
    check(sanitized.customs.isEmpty && sanitized.selectedID=="ant","persisted custom paths cannot escape asset folder")
    try! Data("{broken".utf8).write(to:config)
    let recovered=CharacterLibrary(folder:base)
    check(recovered.selectedID=="ant" && !recovered.loadNotice.isEmpty,"damaged appearance settings fall back")
    check((try! String(contentsOf:config))=="{broken","damaged settings are not overwritten on read")
    print("CHARACTER CHECKS: \(count) passed")
    print("Evidence: \(base.path)")
}

func characterBitmap(width:Int,height:Int,_ draw:(CGContext)->Void)->Data {
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    let context=NSGraphicsContext(bitmapImageRep:bitmap)!,c=context.cgContext
    NSGraphicsContext.saveGraphicsState();c.translateBy(x:0,y:Double(height));c.scaleBy(x:1,y:-1)
    NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:true)
    draw(c);context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using:.png,properties:[:])!
}

func renderCharacters(to directory:String) {
    let dir=URL(fileURLWithPath:directory);try! FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
    CharacterLibrary.shared=CharacterLibrary(folder:dir.appendingPathComponent("render-settings"),writable:false)
    let world=World(width:1440,height:900,seed:12);world.antAvatarEnabled=true
    let contact=characterBitmap(width:1440,height:900){c in
        fillRound(CGRect(x:0,y:0,width:1440,height:900),Ink.cream,0)
        label("今天，让谁占领你的桌面？",58,35,34,Ink.forest,.bold,width:1260)
        label("八种形象 · 一键切换 · 也可以换成你自己的图片",61,89,16,Ink.muted,width:1250)
        for (i,skin) in CharacterLibrary.shared.catalog.enumerated() {
            try! CharacterLibrary.shared.select(skin.id)
            let x=50+(i%4)*345,y=151+(i/4)*347
            fillRound(CGRect(x:x,y:y,width:325,height:327),NSColor(hex:0xE8ECE3),22)
            c.saveGState();c.translateBy(x:Double(x)+162,y:Double(y)+135);c.scaleBy(x:7,y:7)
            CharacterArt.draw(c,bug:Bug(id:i,species:.ant,p:.zero),clock:0);c.restoreGState()
            label(skin.name,Double(x)+12,Double(y)+252,23,Ink.forest,.bold,width:301,align:.center)
            label(skin.tag,Double(x)+12,Double(y)+287,13,Ink.muted,width:301,align:.center)
        }
    }
    try! contact.write(to:dir.appendingPathComponent("八款角色.png"))
    for skin in CharacterLibrary.shared.catalog {
        try! CharacterLibrary.shared.select(skin.id)
        let data=characterBitmap(width:1200,height:400){c in
            fillRound(CGRect(x:0,y:0,width:1200,height:400),Ink.cream,0)
            for n in 0..<4 {
                var bug=Bug(id:n,species:.ant,p:.zero,phase:1.7,speed:n==1 ? 40 : 0)
                bug.bitePulse=n==2 ? 0.3 : 0;bug.fightTime=n==3 ? 0.3 : 0
                c.saveGState();c.translateBy(x:150+Double(n)*300,y:190);c.scaleBy(x:6,y:6);CharacterArt.draw(c,bug:bug,clock:0.4)
                if n==3 {CharacterArt.accent(c,effect:skin.effect,t:0.25,size:0.8,color:NSColor(hex:skin.color))};c.restoreGState()
                label(["待机","迈步","吃东西","出招"][n],Double(n)*300,344,18,Ink.forest,.semibold,width:300,align:.center)
            }
        }
        try! data.write(to:dir.appendingPathComponent(skin.id+"-动作.png"))
    }
    try! CharacterLibrary.shared.select("nailong")
    let gallery=CharacterGallery(world:world)
    let content=gallery.window!.contentView!
    let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds)!
    content.cacheDisplay(in:content.bounds,to:bitmap)
    try! bitmap.representation(using:.png,properties:[:])!.write(to:dir.appendingPathComponent("Mac角色换装面板.png"))
    let controls=ControlView(world:world)
    let controlBitmap=controls.bitmapImageRepForCachingDisplay(in:controls.bounds)!
    controls.cacheDisplay(in:controls.bounds,to:controlBitmap)
    try! controlBitmap.representation(using:.png,properties:[:])!.write(to:dir.appendingPathComponent("Mac控制面板.png"))
    print(dir.path)
}
