import Foundation

struct EggShelter:Codable {var p:V
    var rect:CGRect {CGRect(x:p.x-32,y:p.y-24,width:64,height:48)}
    func contains(_ point:V)->Bool {rect.contains(CGPoint(x:point.x,y:point.y))}
}
extension Egg {
    var emission:Double {min(1,max(0,(layAge ?? 3)/2.8))}
    var shownPoint:V {
        guard let start=layStart else {return p}
        let t=emission,u=t*t*(3-2*t)
        return start+(p-start)*u
    }
}
extension World {
    func markShelter(_ point:V) {
        let p=safe(point)
        if let i=shelters.firstIndex(where:{$0.p.distance(p)<35}) {shelters.remove(at:i);say("这处藏卵位置已取消。",force:true);return}
        if shelters.count>=6 {say("已有六处藏卵位置，点原位置可以取消。",force:true);return}
        shelters.append(EggShelter(p:p));say("藏卵处已记住，附近成虫会过来产卵。再点此处可取消。",force:true)
    }
    func shelterGoal(_ b:Bug)->V? {
        guard b.breeder,b.adult,b.flight == nil,(b.species == .roach ? roachBirthTimer : antBirthTimer)<6 else {return nil}
        return shelters.min(by:{$0.p.distance(b.p)<$1.p.distance(b.p)}).map{s in
            safeBug(s.p+V(x:-1,y:0)*(radius(b)+33),b)
        }
    }
    func emittedEgg(_ parent:Bug,id:Int)->Egg {
        let dir=upright(parent.species) ? V(x:0,y:-1) : V(x:cos(parent.angle),y:sin(parent.angle)),k=scale(for:parent)
        let from=parent.p-dir*(upright(parent.species) ? 15 : (petID(parent.species)=="ant" ? 8 : 20))*k
        var p=safe(parent.p-dir*(upright(parent.species) ? 27 : (petID(parent.species)=="ant" ? 20 : 40))*k)
        if let place=shelters.min(by:{$0.p.distance(parent.p)<$1.p.distance(parent.p)}),place.p.distance(parent.p)<radius(parent)+100 {p=place.p+V(x:0,y:8)}
        var e=Egg(id:id,species:parent.species,p:p,hatchTime:parent.species == .roach ? 28 : 22,generation:parent.generation+1,brood:parent.species == .roach ? 3 : 1)
        e.layStart=from;e.layAge=0;e.parentID=parent.id
        return e
    }
    func hatchPoint(_ e:Egg)->V {
        let p=shelters.first(where:{$0.contains(e.p)}).map{$0.p+V(x:45,y:27)} ?? e.p
        return safe(p+V(x:random.range(-6,6),y:random.range(-6,6)))
    }
    func eggOccluded(_ e:Egg)->Bool {e.emission>0.8 && shelters.contains{$0.contains(e.p)} && !(tool == .observe && watchedID==e.id)}
}
