import Foundation

struct RoachFlight: Codable {
    var start:V;var c1:V;var c2:V;var end:V
    var elapsed:Double=0;var duration:Double=3;var height:Double=45
    var progress:Double {min(1,max(0,elapsed/duration))}
    var lift:Double {sin(progress * .pi)*height}
    var open:Double {min(1,min(progress/0.12,(1-progress)/0.16))}
    func point(_ t:Double)->V {
        let u=1-t
        return start*(u*u*u)+c1*(3*u*u*t)+c2*(3*u*t*t)+end*(t*t*t)
    }
    func tangent(_ t:Double)->V {
        let u=1-t
        return (c1-start)*(3*u*u)+(c2-c1)*(6*u*t)+(end-c2)*(3*t*t)
    }
}
extension World {
    // Points remain the actual visible body centers, so mouse hits and grabs match the wings.
    @discardableResult func beginFlight(_ b:inout Bug,awayFrom source:V?=nil)->Bool {
        guard !paused,mode != .result,b.species == .roach,b.adult,b.flight == nil,
              b.flipped<=0,(b.layTime ?? 0)<=0,(b.webTime ?? 0)<=0,b.id != grabbedID,
              bugs.filter({$0.flight != nil}).count<3 else {return false}
        var direction=source.map{(b.p-$0).unit} ?? V(x:cos(flightRandom.range(-.pi,.pi)),y:sin(flightRandom.range(-.pi,.pi)))
        if direction.length<0.1 {direction=V(x:1,y:-0.4).unit}
        var end=safeBug(b.p+direction*flightRandom.range(310,620),b)
        if end.distance(b.p)<90 {end=safeBug(V(x:field.midX*2-b.p.x,y:field.midY*2-b.p.y),b)}
        guard end.distance(b.p)>45 else {return false}
        let span=end-b.p,side=V(x:-span.unit.y,y:span.unit.x)*flightRandom.range(-160,160)
        let c1=safeBug(b.p+span*0.28+side,b),c2=safeBug(b.p+span*0.7-side*0.5,b)
        b.flight=RoachFlight(start:b.p,c1:c1,c2:c2,end:end,duration:flightRandom.range(2.3,3.8)+b.bulkValue*0.8,height:min(80,35+scale(for:b)*7))
        b.flightWait=flightRandom.range(18,42);b.opponentID=nil;b.fightTarget=nil;b.fightTime=0;b.scared=0
        return true
    }
    @discardableResult func scareRoaches(at source:V?=nil)->Int {
        guard !paused,mode != .result else {say("先继续运行，再惊飞蟑螂。",force:true);return 0}
        let order=bugs.indices.sorted {a,b in
            if let p=source {return bugs[a].p.distance(p)<bugs[b].p.distance(p)}
            return bugs[a].bulkValue>bugs[b].bulkValue
        }
        var count=0
        for i in order {
            if let p=source,bugs[i].p.distance(p)>radius(bugs[i])+250 {continue}
            var b=bugs[i]
            if beginFlight(&b,awayFrom:source) {bugs[i]=b;count += 1}
            if count>=3 {break}
        }
        if source == nil {say(count>0 ? "蟑螂惊飞了，展开翅膀绕飞后落地。" : "等成蟑挣脱蛛丝后再试。",force:true)}
        if count>0 {record("蟑螂惊飞：\(count)只成蟑离地避让，随后落回桌面")}
        return count
    }
    func fly(_ b:inout Bug,_ dt:Double)->Bool {
        guard var f=b.flight else {return false}
        f.elapsed=min(f.duration,f.elapsed+dt)
        let t=f.progress,tangent=f.tangent(t)
        if tangent.length>0.01 {b.angle=atan2(tangent.y,tangent.x)}
        b.p=safeBug(f.point(t),b);b.phase += dt*90;b.speed=200
        b.opponentID=nil;b.fightTarget=nil;b.fightTime=0
        if t>=1 {b.flight=nil;b.p=safeBug(f.end,b);b.wander=b.p;b.wanderTime=0;b.cooldown=max(b.cooldown,0.65);b.speed=0}
        else {b.flight=f}
        return true
    }
}
