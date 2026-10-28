import Foundation
func runEggSprayTests(_ check:(Bool,String)->Void) {
    func empty()->World {let w=World(width:1440,height:900,seed:88);w.bugs=[];w.eggs=[];w.foods=[];w.bugSerial=1000;w.invasionTimer=10000;w.autoFoodTime = -10000;w.roachBirthTimer=10000;w.antBirthTimer=10000;return w}
    let nursery=empty();nursery.markShelter(V(x:600,y:400))
    check(nursery.shelters.count==1,"folder position can be marked without filesystem access")
    nursery.markShelter(V(x:600,y:400));check(nursery.shelters.isEmpty,"clicking the same folder position removes its shelter")
    for n in 0..<9 {nursery.markShelter(V(x:150+Double(n)*100,y:400))}
    check(nursery.shelters.count==6,"folder hiding regions have a fixed budget")
    let w=empty();w.markShelter(V(x:600,y:400));var mother=Bug(id:1,species:.roach,p:V(x:535,y:400));mother.breeder=true;w.bugs=[mother];w.roachBirthTimer=0;w.lifecycle(0.05)
    check(!w.eggs.isEmpty && w.eggs[0].parentID==1 && w.eggs[0].layAge==0 && w.bugs[0].layTime==2.8,"natural birth creates an egg attached to its laying parent")
    let tail=w.eggs[0].shownPoint,final=w.eggs[0].p
    check(tail != final && w.eggs[0].emission==0,"egg begins inside the abdomen rather than appearing at its final position")
    let motherAt=w.bugs[0].p;w.update(0.05)
    check(w.bugs[0].p==motherAt,"mother stops moving during egg extrusion")
    var parent=w.bugs[0];check(!w.beginFlight(&parent),"laying mother cannot take off before extrusion finishes")
    w.lifecycle(1.35)
    check(w.eggs[0].shownPoint.distance(tail)>1 && w.eggs[0].shownPoint.distance(final)>1 && w.eggs[0].age==0,"egg visibly slides out before incubation begins")
    w.lifecycle(1.5)
    check(w.eggs[0].emission==1 && w.eggOccluded(w.eggs[0]),"completed egg slips behind the chosen folder mask")
    w.tool = .observe;w.watchedID=w.eggs[0].id
    check(!w.eggOccluded(w.eggs[0]),"observing an egg temporarily reveals its true hidden position")
    w.tool = .food;w.lifecycle(29)
    check(w.bugs.contains{!$0.adult && !w.shelters[0].contains($0.p)},"hidden eggs hatch into visible young outside the folder edge")
    let saved=try! w.saveData();let restored=empty();try! restored.restore(saved)
    check(restored.shelters.count==1 && restored.bugs.count==w.bugs.count,"folder hiding positions survive restart without losing the colony")
    let spray=empty();spray.ecologyInteractive=true
    var flying=Bug(id:1,species:.roach,p:V(x:500,y:400));spray.bugs=[flying,Bug(id:2,species:.ant,p:V(x:530,y:400)),Bug(id:3,species:.ant,p:V(x:1100,y:400))]
    _ = spray.beginFlight(&flying);spray.bugs[0]=flying
    spray.eggs=[Egg(id:99,species:.roach,p:V(x:500,y:400),hatchTime:28,generation:2)]
    spray.tool = .spray;spray.press(V(x:500,y:400))
    check(spray.bugs.count==1 && spray.bugs[0].id==3 && spray.corpses.count==2,"insecticide kills nearby flying and ground bugs while distant bugs survive")
    check(spray.splats.count==1 && !spray.splats[0].crushed && spray.eggs.count==1,"spray leaves an intact corpse and smaller juice while eggs remain")
    check(spray.corpses.allSatisfy{$0.bug.flight==nil} && spray.reports.last!.events.contains{$0.contains("杀虫剂")},"spray kills stop flight and enter the daily report")
    let mist=spray.sprays.count;spray.press(V(x:500,y:400));check(spray.sprays.count==mist,"continuous spray is rate limited")
    spray.bugs.append(Bug(id:4,species:.ant,p:V(x:500,y:400)));spray.update(0.05)
    check(!spray.bugs.contains{$0.id==4},"bugs entering an active spray cloud are also killed")
    spray.paused=true;let age=spray.sprays[0].age;spray.update(0.05);spray.sprayCooldown=0;spray.spray(V(x:1100,y:400))
    check(spray.bugs.count==1 && spray.sprays[0].age==age,"pause freezes mist and prevents spray kills")
    spray.paused=false;spray.tool = .clean;spray.sweep(V(x:500,y:400))
    check(spray.corpses.isEmpty && spray.splats.isEmpty,"broom cleans insecticide corpses and their liquid")
    let reload=empty();try! reload.restore(spray.saveData())
    check(reload.sprays.isEmpty,"reopening does not replay or retain lethal spray clouds")
    for _ in 0..<30 {spray.sprayCooldown=0;spray.spray(V(x:600,y:500))}
    check(spray.sprays.count<=8,"heavy spray use keeps cloud rendering bounded")
}
