import AppKit

func renderFeatureChecks(to directory:String) {
    try! FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
    func frame(_ name:String,_ w:World,controls:Bool=false) {
        let width=controls ? 324 : 1200,height=controls ? 734 : 800
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        let context=NSGraphicsContext(bitmapImageRep:bitmap)!
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context
        let c=context.cgContext;c.translateBy(x:0,y:CGFloat(height));c.scaleBy(x:1,y:-1)
        NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:true)
        c.setFillColor(Ink.cream.cgColor);c.fill(CGRect(x:0,y:0,width:width,height:height))
        if controls {
            let card=ControlView(world:w);card.clearBeforeDrawing=false;card.draw(card.bounds)
            for view in card.subviews {c.saveGState();c.translateBy(x:view.frame.minX,y:view.frame.minY);view.draw(view.bounds);c.restoreGState()}
        } else {drawArena(w,in:c,showHint:false)}
        context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
        try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:directory).appendingPathComponent(name+".png"))
    }
    func empty()->World {let w=World(width:1200,height:800,seed:42);w.bugs=[];w.eggs=[];w.foods=[];return w}
    let flying=empty();var b=Bug(id:1,species:.roach,p:V(x:600,y:400));b.bulk=0.58;b.shownBulk=0.58;flying.bugs=[b]
    _ = flying.beginFlight(&b);let duration=b.flight!.duration
    for (n,t) in [0.05,0.28,0.56,0.83,1.0].enumerated() {
        var state=b;state.flight!.elapsed=duration*t;_ = flying.fly(&state,0);flying.bugs=[state]
        frame("flight-\(n)",flying)
    }
    let visitors=empty()
    for (n,kind) in InvaderKind.allCases.enumerated() {visitors.invaders.append(Invader(id:100+n,kind:kind,p:V(x:230+Double(n%3)*350,y:230+Double(n/3)*300),phase:1.4,health:100,cooldown:1.4))}
    frame("visitors",visitors)
    let lay=empty();lay.markShelter(V(x:650,y:400));var parent=Bug(id:7,species:.roach,p:V(x:570,y:400),angle:.pi);parent.breeder=true;parent.bulk=0.28;parent.shownBulk=0.28;lay.bugs=[parent];lay.eggs=[lay.emittedEgg(parent,id:20)]
    for (n,age) in [0.0,1.4,2.8].enumerated() {lay.eggs[0].layAge=age;lay.bugs[0].layTime=2.8-age;frame("egg-extrusion-\(n)",lay)}
    let poison=empty();poison.ecologyInteractive=true;poison.bugs=[Bug(id:1,species:.roach,p:V(x:600,y:400)),Bug(id:2,species:.ant,p:V(x:640,y:390))];poison.spray(V(x:600,y:400));poison.sprays[0].age=0.25
    frame("insecticide",poison)
    frame("controls",World(width:1200,height:800,seed:42),controls:true)
}
