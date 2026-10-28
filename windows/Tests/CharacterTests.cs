using System;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DesktopCritters.Core;
namespace DesktopCritters;
public static class CharacterTests {
 public static void Run(string directory) {
  int checks=0;void Check(bool ok,string name){if(!ok)throw new Exception("FAIL: "+name);checks++;Console.WriteLine("PASS: "+name);}
  var folder=Path.Combine(directory,"appearance-test");var library=new CharacterLibrary(folder);CharacterLibrary.Shared=library;
  Check(library.Catalog.Count==8&&library.Catalog.Select(s=>s.Id).Distinct().Count()==8,"eight unique character presets");
  foreach(var skin in library.Catalog){for(int pose=0;pose<4;pose++)Check(library.Image(skin.Id,pose)!=null,"decode "+skin.Id+" pose "+pose);library.Select(skin.Id);Check(new CharacterLibrary(folder).Selected==skin.Id,"persist "+skin.Id);}
  var world=new World(1440,900,12);string before=world.SaveJson();library.Select("ultraman");world.AntAvatarEnabled=library.Enabled;Check(world.SaveJson()==before,"skin switch leaves ecology unchanged");
  var ant=new Bug{Id=900,Species=Species.Ant,P=new V(300,300),Angle=Math.PI/2};Check(world.BodyHit(ant,new V(300,284)),"upright avatar head target");Check(!world.BodyHit(ant,new V(345,300)),"avatar target excludes distant blank space");var safe=world.SafeBug(new V(-100,-100),ant);Check(safe.X>=43&&safe.Y>=55,"avatar stays within desktop");
  library.Perform(world,new[]{900});Check(library.Performing(900,world.Clock+.1)!=null&&library.Performing(901,world.Clock+.1)==null,"performance targets requested character");Check(library.Performing(900,world.Clock+2)==null,"performance expires");Check(world.SaveJson()==before,"performance does not inflict damage");
  world.Bugs.Clear();world.Bugs.Add(ant);using(var d=new DrawingVisual().RenderOpen()){Check(CharacterArt.Fight(d,new Fight{Attacker=900,From=ant.P,To=new V(350,300)},world),"skin effect uses real ant attacker");Check(!CharacterArt.Fight(d,new Fight{Attacker=-1},world),"unrelated attacks retain original effects");}
  library.Select("ant");Check(!library.Enabled&&new CharacterLibrary(folder).Selected=="ant","restore original ants");try{library.Select("missing");Check(false,"invalid selection");}catch(InvalidDataException){Check(library.Selected=="ant","invalid selection preserves original");}
  string source=Path.Combine(directory,"my-character.png");using(var stream=Application.GetResourceStream(new Uri("pack://application:,,,/Characters/nailong.png"))!.Stream)using(var output=File.Create(source))stream.CopyTo(output);
  var custom=library.Import(source);Check(custom.Custom==true&&library.Selected==custom.Id,"local image import selects character");var image=library.Image(custom.Id)!;Check(Math.Max(image.PixelWidth,image.PixelHeight)<=1024,"custom image normalized");Check(File.Exists(Path.Combine(folder,"CustomCharacters","Originals",custom.Id+".png")),"original image retained");Check(new CharacterLibrary(folder).Image(custom.Id)!=null,"custom image reopens");
  string invalid=Path.Combine(directory,"invalid.png");File.WriteAllText(invalid,"invalid");try{library.Import(invalid);Check(false,"invalid image");}catch{Check(library.Selected==custom.Id,"bad import preserves current choice");}
  string invisible=Path.Combine(directory,"invisible.png");var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(BitmapSource.Create(16,16,96,96,PixelFormats.Bgra32,null,new byte[16*16*4],16*4)));using(var output=File.Create(invisible))encoder.Save(output);try{library.Import(invisible);Check(false,"transparent image");}catch(InvalidDataException){Check(library.Selected==custom.Id,"transparent image is rejected");}
  var config=Path.Combine(folder,"appearance-v1.json");File.WriteAllText(config,"{\"version\":1,\"selected\":\"custom-bad\",\"customs\":[{\"id\":\"custom-bad\",\"file\":\"../outside.png\",\"custom\":true}]}");var sanitized=new CharacterLibrary(folder);Check(sanitized.Customs.Count==0&&sanitized.Selected=="ant","custom paths cannot escape local folder");File.WriteAllText(config,"{broken");Check(new CharacterLibrary(folder).Selected=="ant"&&File.ReadAllText(config)=="{broken","damaged settings preserved with fallback");
  CharacterLibrary.Shared=new CharacterLibrary(Path.Combine(directory,"appearance-smoke"));Console.WriteLine("CHARACTER CHECKS: "+checks+" passed");
 }
}
