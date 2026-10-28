import AppKit

// Small native creatures repeat the same leg cycle. Rasterize each pose once so hundreds
// of tiny legs do not enqueue thousands of separate GPU paths on every desktop frame.
enum CreatureFrames {
    private static var frames:[String:NSImage]=[:]
    private static var building=false
    static var count:Int {frames.count}
    static func draw(_ c:CGContext,_ bug:Bug,alpha:Double,dead:Bool)->Bool {
        guard !building,bug.flight==nil else{return false}
        let transform=c.ctm,scale=max(hypot(transform.a,transform.b),hypot(transform.c,transform.d))
        guard scale<=6 else{return false} // Keep large specimens at full vector/photo detail.
        let phase=dead ? 0 : Int(floor((bug.phase.truncatingRemainder(dividingBy:2 * .pi)+2 * .pi).truncatingRemainder(dividingBy:2 * .pi)/(2 * .pi)*16))
        let key="\(bug.species.rawValue)-\(bug.morph)-\(phase)-\(dead)"
        let rect=bug.species == .roach ? CGRect(x:-52,y:-44,width:150,height:88) : CGRect(x:-24,y:-18,width:50,height:36)
        if frames[key]==nil {
            if frames.count>=192 {frames.removeAll(keepingCapacity:true)}
            let density=4.0
            guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(rect.width*density),pixelsHigh:Int(rect.height*density),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),let context=NSGraphicsContext(bitmapImageRep:bitmap) else{return false}
            NSGraphicsContext.saveGraphicsState()
            let raster=context.cgContext;raster.translateBy(x:0,y:rect.height*density);raster.scaleBy(x:density,y:-density);raster.translateBy(x:-rect.minX,y:-rect.minY)
            NSGraphicsContext.current=NSGraphicsContext(cgContext:raster,flipped:true)
            building=true;var shown=bug;shown.phase=Double(phase)/16*2 * .pi
            Creatures.bug(raster,shown,alpha:1,dead:dead)
            building=false;context.flushGraphics();NSGraphicsContext.restoreGraphicsState()
            guard let image=bitmap.cgImage else{return false}
            frames[key]=NSImage(cgImage:image,size:rect.size)
        }
        frames[key]?.draw(in:rect,from:.zero,operation:.sourceOver,fraction:alpha,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.high.rawValue])
        return true
    }
}
