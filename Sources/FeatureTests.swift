import Foundation

func runFlightVisitorTests(_ check:(Bool,String)->Void) {
    func empty()->World {
        let w=World(width:1440,height:900,seed:113);w.bugs=[];w.eggs=[];w.foods=[];w.bugSerial=1000
        w.invasionTimer=10000;w.autoFoodTime = -10000;w.roachBirthTimer=10000;w.antBirthTimer=10000
        return w
    }
    let w=empty();var b=Bug(id:1,species:.roach,p:V(x:500,y:400))
    w.bugs=[b]
    var ant=Bug(id:2,species:.ant,p:b.p)
    check(!w.beginFlight(&ant),"ants remain ground creatures")
    var young=b;young.growth=0.7
    check(!w.beginFlight(&young),"wingless roach nymphs cannot fly")
    var webbed=b;webbed.webTime=2
    check(!w.beginFlight(&webbed),"spider silk prevents roach takeoff")
    w.grabbedID=1;check(!w.beginFlight(&b),"held roaches cannot escape by flight");w.grabbedID=nil
    check(w.beginFlight(&b),"adult roach starts a real flight")
    w.bugs[0]=b;let start=b.p
    check(b.flight!.point(0)==start && b.flight!.point(1)==b.flight!.end,"curved flight has continuous takeoff and landing endpoints")
    w.paused=true;w.update(0.05)
    check(w.bugs[0].flight!.elapsed==0 && w.bugs[0].p==start,"pause freezes wings and flight position")
    check(w.scareRoaches()==0,"manual scare respects pause")
    w.paused=false
    for _ in 0..<20 {w.update(0.05)}
    check(w.bugs[0].p.distance(start)>20 && w.bugs[0].flight!.lift>10 && w.bugs[0].flight!.open>0.9,"flying body travels while wings open and shadow lifts")
    let p=w.bugs[0].p
    check(w.bodyHit(w.bugs[0],p),"flying hit area follows its visible body")
    _ = w.addFood(p,kind:.pizza,announce:false);let portions=w.foods[0].portions
    w.bugs[0].cooldown=0;w.biteBug(at:0,food:0)
    check(w.foods[0].portions==portions,"flying roaches cannot eat ground food midair")
    w.bugs.append(Bug(id:2,species:.ant,p:p));let hp=w.bugs[0].health
    w.resolveCrowding(0.6)
    check(w.bugs[0].health==hp && w.bugs[0].opponentID==nil,"ground duels do not hit airborne roaches")
    let data=try! w.saveData();let restored=empty();try! restored.restore(data)
    check(restored.bugs.map{$0.id}==w.bugs.map{$0.id} && restored.bugs.allSatisfy{$0.flight==nil},"reopening preserves creatures and safely ends transient flights")
    w.swat(w.bugs[0].p)
    check(!w.bugs.contains{$0.id==1} && w.corpses.contains{$0.bug.id==1 && $0.bug.flight==nil} && w.splats.count==1,"airborne roach can be swatted and leaves a grounded corpse with juice")
    let land=empty();var flyer=Bug(id:10,species:.roach,p:V(x:600,y:450));land.bugs=[flyer];_ = land.beginFlight(&flyer)
    for _ in 0..<120 {_ = land.fly(&flyer,0.05)}
    check(flyer.flight==nil && flyer.cooldown>0 && (flyer.flightWait ?? 0)>0,"flight finishes and returns to ground behavior with a takeoff cooldown")
    let cap=empty();cap.bugs=(0..<8).map{Bug(id:$0,species:.roach,p:V(x:200+Double($0)*100,y:400))}
    check(cap.scareRoaches()==3 && cap.bugs.filter{$0.flight != nil}.count==3,"scare starts a bounded three-roach flight group")
    check(cap.scareRoaches()==0,"repeated clicks cannot grow the airborne group without limit")
    cap.resize(width:1200,height:800)
    check(cap.bugs.allSatisfy{$0.flight==nil && $0.p.x.isFinite && $0.p.y.isFinite},"display resize safely lands current flights")
    let natural=empty();var scout=Bug(id:12,species:.roach,p:V(x:500,y:400));scout.flightWait=0;natural.bugs=[scout];natural.update(0.05)
    check(natural.bugs[0].flight != nil,"unoccupied adult roach takes off naturally")
    let missed=empty();missed.bugs=[Bug(id:7,species:.roach,p:V(x:700,y:400))];missed.swat(V(x:500,y:400))
    check(missed.bugs[0].flight != nil && missed.corpses.isEmpty,"nearby missed slipper slap startles a surviving roach into flight")
    let legacy=empty();var old=try! JSONSerialization.jsonObject(with:data) as! [String:Any]
    var oldBugs=old["bugs"] as! [[String:Any]];for i in oldBugs.indices {oldBugs[i].removeValue(forKey:"flight");oldBugs[i].removeValue(forKey:"flightWait")};old["bugs"]=oldBugs
    try! legacy.restore(JSONSerialization.data(withJSONObject:old))
    check(legacy.bugs.count==2,"old v1 saves without flight fields remain readable")
    check(InvaderKind.allCases.count==5,"five foreign species are available")
    for kind in [InvaderKind.centipede,.snake,.rat] {
        let v=empty();check(v.summonInvader(kind),"new foreign visitor can enter: "+kind.title)
        let at=v.invaders[0].p;v.bugs=(0..<3).map{Bug(id:$0,species:.ant,p:at+V(x:Double($0)*5,y:0))}
        for i in v.bugs.indices {v.bugs[i].health=100}
        v.invaders[0].cooldown=0
        if kind == .rat {_ = v.addFood(at,kind:.pizza,announce:false)}
        let food=v.foods.first?.portions ?? 0;v.setRelations(.truce,reason:"test");v.updateInvaders(0.05)
        let hit=v.bugs.filter{$0.health<100}.count
        check(hit>0 && v.relations == .truce && v.invaders[0].health<kind.baseHealth,"visitor causes real damage and treaty-safe counterattacks: "+kind.title)
        if kind == .snake {check(hit==1 && v.invaders[0].cooldown==kind.cadence,"snake strikes a single target then recoils")}
        if kind == .centipede {check(hit==2 && v.invaders[0].cooldown<1,"centipede uses a rapid two-target bite cadence")}
        if kind == .rat {check(v.invaders[0].stolen==48 && v.foods[0].portions==food-48,"rat raids consume real snack portions")}
        let saved=try! v.saveData();let reopen=empty();try! reopen.restore(saved)
        check(reopen.invaders[0].kind==kind,"new visitor survives save and restore: "+kind.title)
        v.invaders[0].health=0;v.sweep(v.invaders[0].p)
        check(v.invaders.isEmpty,"new visitor remains can be swept away: "+kind.title)
    }
}
