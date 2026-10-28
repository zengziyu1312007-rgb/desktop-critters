import AppKit

func runTeamTests(_ check:(Bool,String)->Void) {
    let folder=FileManager.default.temporaryDirectory.appendingPathComponent("DesktopCritters-TeamTests-"+UUID().uuidString)
    let library=CharacterLibrary(folder:folder);CharacterLibrary.shared=library
    let w=World(width:1440,height:900,seed:12)
    func canonical()->Data {let object=try! JSONSerialization.jsonObject(with:w.saveData());return try! JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])}
    let before=canonical()
    check(library.leftID=="roach" && library.selectedID=="ant","fresh install defaults to original pair")
    check(library.all.count==11 && library.all.allSatisfy{library.image(for:$0.id) != nil},"both teams share eleven decodable presets")
    try! library.select("rat",for:.roach);try! library.select("nailong",for:.ant);library.apply(to:w)
    check(library.leftID=="rat" && library.selectedID=="nailong","left and right selections are independent")
    check(canonical()==before,"changing both teams preserves ecology, reports and random state")
    let reload=CharacterLibrary(folder:folder)
    check(reload.leftID=="rat" && reload.selectedID=="nailong","both choices survive restart")
    try! library.select("nailong",for:.roach);library.apply(to:w)
    check(library.leftID==library.selectedID && w.teamName(.roach) != w.teamName(.ant),"same character remains two distinguishable teams")
    let left=Bug(id:884,species:.roach,p:V(x:400,y:400),angle:.pi/2)
    check(w.bodyHit(left,V(x:400,y:384)) && !w.bodyHit(left,V(x:442,y:400)),"left upright character hit target follows its actual body")
    check(w.safeBug(V(x:-20,y:-20),left).x>=w.field.minX+18,"left uploaded shape stays on desktop")
    var nativeLeft=left
    check(!w.beginFlight(&nativeLeft),"non-roach left pet does not inherit invisible roach wings")
    try! library.select("roach",for:.ant);library.apply(to:w)
    var right=Bug(id:881,species:.ant,p:V(x:500,y:400))
    check(w.beginFlight(&right),"roach chosen on right team can fly")
    w.bugs=[right];try! library.select("rat",for:.ant);library.apply(to:w)
    check(w.bugs[0].flight==nil,"switching flying roach to another pet lands safely")
    let native=Bug(id:882,species:.ant,p:V(x:450,y:400))
    check(w.bodyHit(native,V(x:475,y:400)),"rat on right has full body hit target")
    let first=try! library.importImage(Bundle.main.url(forResource:"nailong",withExtension:"png",subdirectory:"Characters")!,for:.roach)
    let second=try! library.importImage(Bundle.main.url(forResource:"niulai",withExtension:"png",subdirectory:"Characters")!,for:.ant)
    check(first.id != second.id && library.leftID==first.id && library.selectedID==second.id,"two different custom images can be assigned independently")
    let customReload=CharacterLibrary(folder:folder)
    check(customReload.leftID==first.id && customReload.selectedID==second.id && customReload.image(for:first.id) != nil && customReload.image(for:second.id) != nil,"both custom images and choices survive restart")
    do {try library.select("missing",for:.roach);check(false,"bad left selection rejected")} catch {check(library.leftID==first.id && library.selectedID==second.id,"invalid left selection preserves both teams")}
    library.apply(to:w);w.bugs=[left,Bug(id:881,species:.ant,p:V(x:450,y:400))];w.eggs=[];w.corpses=[];w.splats=[];w.ecologyInteractive=true
    let egg=w.emittedEgg(left,id:990)
    check(egg.layStart!.x==left.p.x && egg.layStart!.y>left.p.y,"upright custom pet extrudes egg from the visible lower body")
    w.eggs=[egg];w.markShelter(egg.p);w.eggs[0].layAge=3
    check(w.eggOccluded(w.eggs[0]),"custom team eggs still hide in folder regions")
    w.spray(V(x:425,y:400))
    check(w.bugs.isEmpty && w.corpses.count==2 && w.eggs.count==1,"insecticide kills both custom teams and preserves their egg")
    check(w.splats.isEmpty,"custom characters do not leak invisible roach texture effects")
    w.sweep(V(x:425,y:400));check(w.corpses.isEmpty,"broom cleans both custom character corpses")
    w.roachBirthTimer=10000;w.antBirthTimer=10000;w.eggs=[Egg(id:991,species:.roach,p:V(x:500,y:500),hatchTime:1,generation:2)];w.lifecycle(2)
    check(w.bugs.contains{$0.species == .roach && !$0.adult} && w.leftPetID==first.id,"newborns inherit custom left team appearance")
    check(w.reportText.contains("左队") && w.reportText.contains("右队"),"report identifies both teams after customization")
    try! library.restorePair();library.apply(to:w)
    check(library.leftID=="roach" && library.selectedID=="ant" && library.customs.count==2,"restore default pair retains uploaded library")
    // Migration must retain the old right-side character and untouched configuration until a choice is saved.
    let file=folder.appendingPathComponent("appearance-v1.json")
    let old="{\"version\":1,\"selected\":\"niulai\",\"customs\":[]}"
    try! Data(old.utf8).write(to:file)
    let migrated=CharacterLibrary(folder:folder)
    check(migrated.leftID=="roach" && migrated.selectedID=="niulai","legacy single-side appearance migrates to right team")
    check((try! String(contentsOf:file))==old,"migration does not overwrite old settings on read")
    let damaged="{\"version\":1,\"selected\":\"niulai\",\"left\":\"missing\",\"customs\":[]}"
    try! Data(damaged.utf8).write(to:file)
    let fallback=CharacterLibrary(folder:folder)
    check(fallback.leftID=="roach" && fallback.selectedID=="niulai","missing left asset falls back without replacing right team")
    print("Team fixtures: "+folder.path)
}

func renderTeamChecks(to dir:URL) {
    CharacterLibrary.shared=CharacterLibrary(folder:dir.appendingPathComponent("team-render-settings"),writable:false)
    let library=CharacterLibrary.shared
    for (name,left,right) in [("奶龙对老鼠","nailong","rat"),("同款双队","usagi","usagi"),("右队蟑螂飞行","capybara","roach")] {
        let w=World(width:1200,height:800,seed:42);w.bugs=[];w.eggs=[];w.foods=[]
        try! library.select(left,for:.roach);try! library.select(right,for:.ant);library.apply(to:w)
        for (i,team) in [Species.roach,.ant].enumerated() {
            for n in 0..<5 {var b=Bug(id:i*10+n,species:team,p:V(x:210+Double(i)*540+Double(n%2)*115,y:275+Double(n/2)*140),angle:i==0 ? 0 : .pi,phase:1.6,speed:30,growth:n==4 ? 0.3 : 1);b.bulk=n==0 ? 0.7 : 0.12;b.shownBulk=b.bulk;w.bugs.append(b)}
        }
        if right=="roach" {var b=w.bugs[5];_ = w.beginFlight(&b);b.flight?.elapsed=1;_ = w.fly(&b,0);w.bugs[5]=b}
        _ = w.addFood(V(x:600,y:470),kind:.pizza,announce:false)
        let data=characterBitmap(width:1200,height:800){c in
            fillRound(CGRect(x:0,y:0,width:1200,height:800),Ink.cream,0)
            label(w.teamName(.roach),80,50,28,Ink.forest,.bold,width:450)
            label(w.teamName(.ant),675,50,28,Ink.forest,.bold,width:450)
            drawArena(w,in:c,showHint:false)
        };try! data.write(to:dir.appendingPathComponent(name+".png"))
        if name=="奶龙对老鼠" {
            let gallery=CharacterGallery(world:w);let content=gallery.window!.contentView!,bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds)!;content.cacheDisplay(in:content.bounds,to:bitmap);try! bitmap.representation(using:.png,properties:[:])!.write(to:dir.appendingPathComponent("双队选择面板.png"))
        }
    }
}
