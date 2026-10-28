using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Microsoft.Win32;
using DesktopCritters.Core;

namespace DesktopCritters;

public sealed class CharacterSkin {
 public string Id {get;set;}=""; public string Name {get;set;}=""; public string Tag {get;set;}="";
 public string Effect {get;set;}="stars"; public uint Color {get;set;}=0x8DCBB8; public string File {get;set;}="";
 public bool? Custom {get;set;} public bool? FacesLeft {get;set;}
}
public sealed class AppearanceConfig {
 public int Version {get;set;}=1; public string Selected {get;set;}="ant"; public string? Left {get;set;} public List<CharacterSkin> Customs {get;set;}=new();
}
public sealed class CharacterLibrary {
 private static readonly JsonSerializerOptions Json=new(){PropertyNameCaseInsensitive=true,PropertyNamingPolicy=JsonNamingPolicy.CamelCase,WriteIndented=true};
 public static CharacterLibrary Shared=new();
 public readonly string Folder; private readonly bool writable;
 public List<CharacterSkin> Catalog {get;private set;}=new(); public List<CharacterSkin> Customs {get;private set;}=new();
 public static readonly CharacterSkin[] Natives={
  new(){Id="roach",Name="蟑螂",Tag="展翅惊飞 · 写实虫体",Effect="",Color=0xA2784E},
  new(){Id="ant",Name="蚂蚁",Tag="小巧搬运 · 围攻抢粮",Effect="",Color=0x486852},
  new(){Id="rat",Name="老鼠",Tag="摇尾小跑 · 争食冲撞",Effect="ram",Color=0x9C8A73}};
 public IEnumerable<CharacterSkin> All=>Natives.Concat(Catalog).Concat(Customs);
 public string Selection(Species side)=>side==Species.Roach?Left:Selected;
 public CharacterSkin? Skin(Species side)=>All.FirstOrDefault(s=>s.Id==Selection(side));
 public string Name(Species side)=>Skin(side)?.Name??(side==Species.Roach?"蟑螂":"蚂蚁");
 public bool CustomRendering(Species side)=>Selection(side)!=(side==Species.Roach?"roach":"ant");
 public void Apply(World world){world.LeftPetId=Left;world.RightPetId=Selected;world.LeftPetName=Name(Species.Roach);world.RightPetName=Name(Species.Ant);foreach(var b in world.Bugs)if(world.PetId(b.Species)!="roach")b.Flight=null;}
 public string Selected {get;private set;}="ant";public string Left {get;private set;}="roach"; public string Notice {get;private set;}="";
 public CharacterSkin? Current=>All.FirstOrDefault(s=>s.Id==Selected); public string DisplayName=>Current?.Name??"原蚂蚁";
 public bool Enabled=>!new[]{"roach","ant","rat"}.Contains(Selected)&&Image(Selected)!=null;
 private readonly Dictionary<string,BitmapSource[]> frames=new();
 private double performedAt=-100;private HashSet<int> performers=new();
 public CharacterLibrary(string? folder=null,bool writable=true) {
  Folder=folder??Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"DesktopCrittersWindows");this.writable=writable;
  using(var resource=Application.GetResourceStream(new Uri("pack://application:,,,/Characters/catalog.json"))?.Stream)if(resource!=null)Catalog=JsonSerializer.Deserialize<List<CharacterSkin>>(resource,Json)??new();
  var path=Path.Combine(Folder,"appearance-v1.json");if(!System.IO.File.Exists(path))return;
  try {
   var saved=JsonSerializer.Deserialize<AppearanceConfig>(System.IO.File.ReadAllText(path),Json)??throw new InvalidDataException();if(saved.Version!=1)throw new InvalidDataException();
   var seen=new HashSet<string>(Catalog.Select(s=>s.Id));
   Customs=saved.Customs.Where(s=>s.Custom==true&&s.Id.StartsWith("custom-")&&s.File==s.Id+".png"&&s.File.Length<90&&!s.File.Contains('/')&&!s.File.Contains('\\')&&seen.Add(s.Id)).Take(32).ToList();
   Selected=Valid(saved.Selected)?saved.Selected:"ant";Left=Valid(saved.Left??"roach")?saved.Left??"roach":"roach";
   if(Selected!=saved.Selected||Left!=(saved.Left??"roach"))Notice="部分形象文件不可用，已恢复对应队伍的默认形象。";
  }catch{Selected="ant";Notice="形象设置读取失败，原文件已保留。";}
 }
 private bool Valid(string id)=>All.Any(s=>s.Id==id)&&Image(id)!=null;
 private void Save(string selected,string left,List<CharacterSkin> items){if(!writable)return;Directory.CreateDirectory(Folder);var file=Path.Combine(Folder,"appearance-v1.json");if(System.IO.File.Exists(file))System.IO.File.Copy(file,Path.Combine(Folder,"appearance-previous.json"),true);var temp=file+".tmp";System.IO.File.WriteAllText(temp,JsonSerializer.Serialize(new AppearanceConfig{Selected=selected,Left=left,Customs=items},Json));System.IO.File.Move(temp,file,true);}
 public void Select(string id,Species side=Species.Ant){if(!Valid(id))throw new InvalidDataException("这个形象文件不可用，请重新导入。");var left=side==Species.Roach?id:Left;var right=side==Species.Ant?id:Selected;Save(right,left,Customs);Selected=right;Left=left;performedAt=-100;performers.Clear();}
 public void RestorePair(){Save("ant","roach",Customs);Selected="ant";Left="roach";performers.Clear();}
 public BitmapSource? Image(string id,int pose=0){
  if(frames.TryGetValue(id,out var cached))return cached[Math.Clamp(pose,0,cached.Length-1)];
  if(new[]{"roach","ant","rat"}.Contains(id)){
   var visual=new DrawingVisual();using(var c=visual.RenderOpen()){double scale=id=="ant"?4:id=="rat"?1.8:1.45;using var q=Art.Transform(c,120,90,sx:scale,sy:scale);CharacterArt.Native(c,id,new Bug{Species=Species.Roach});}
   var bitmap=new RenderTargetBitmap(240,180,96,96,PixelFormats.Pbgra32);bitmap.Render(visual);bitmap.Freeze();frames[id]=new BitmapSource[]{bitmap};return bitmap;
  }
  var skin=All.FirstOrDefault(s=>s.Id==id);if(skin==null)return null;
  try {
   using var stream=skin.Custom==true?System.IO.File.OpenRead(Path.Combine(Folder,"CustomCharacters",skin.File)):Application.GetResourceStream(new Uri("pack://application:,,,/Characters/"+skin.File))!.Stream;
   var decoder=BitmapDecoder.Create(stream,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad);var bitmap=decoder.Frames[0];
   if(skin.Custom==true){bitmap.Freeze();frames[id]=new BitmapSource[]{bitmap};}
   else {int w=bitmap.PixelWidth/2,h=bitmap.PixelHeight/2;frames[id]=Enumerable.Range(0,4).Select(i=>{var part=new CroppedBitmap(bitmap,new Int32Rect(i%2*w,i/2*h,w,h));part.Freeze();return (BitmapSource)part;}).ToArray();}
   return Image(id,pose);
  }catch{return null;}
 }
 public CharacterSkin Import(string path,Species side=Species.Ant) {
  if(Customs.Count>=32)throw new InvalidDataException("已收藏32个自定义形象，请先使用已有形象。");
  long bytes=new FileInfo(path).Length;if(bytes<=0||bytes>20*1024*1024)throw new InvalidDataException("请选一张20MB以内的图片。");
  using var input=System.IO.File.OpenRead(path);var decoder=BitmapDecoder.Create(input,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnDemand);BitmapSource image=decoder.Frames[0];
  int w=image.PixelWidth,h=image.PixelHeight;if(w<=0||h<=0||w>8192||h>8192||(long)w*h>32_000_000)throw new InvalidDataException("图片尺寸过大，请缩小后再导入。");
  if(image.Metadata is BitmapMetadata data){try{var o=data.GetQuery("/app1/ifd/{ushort=274}");int orientation=o==null?1:Convert.ToInt32(o);int angle=orientation==3?180:orientation==6?90:orientation==8?270:0;if(angle!=0)image=new TransformedBitmap(image,new RotateTransform(angle));}catch(NotSupportedException){}}
  double scale=Math.Min(1,1024d/Math.Max(image.PixelWidth,image.PixelHeight));if(scale<1)image=new TransformedBitmap(image,new ScaleTransform(scale,scale));
  var normalized=new FormatConvertedBitmap(image,PixelFormats.Bgra32,null,0);var pixels=new byte[normalized.PixelWidth*normalized.PixelHeight*4];normalized.CopyPixels(pixels,normalized.PixelWidth*4,0);bool any=false;for(int i=3;i<pixels.Length;i+=4)if(pixels[i]>8){any=true;break;}if(!any)throw new InvalidDataException("图片完全透明，请选一张能看见主体的图片。");
  string id="custom-"+Guid.NewGuid().ToString("D"),folder=Path.Combine(Folder,"CustomCharacters");Directory.CreateDirectory(folder);Directory.CreateDirectory(Path.Combine(folder,"Originals"));
  var png=new PngBitmapEncoder();png.Frames.Add(BitmapFrame.Create(normalized));using(var output=System.IO.File.Create(Path.Combine(folder,id+".png")))png.Save(output);
  string extension=Path.GetExtension(path).ToLowerInvariant();if(!new[]{".png",".jpg",".jpeg",".gif"}.Contains(extension))extension=".image";System.IO.File.Copy(path,Path.Combine(folder,"Originals",id+extension));
  string name=Path.GetFileNameWithoutExtension(path);if(name.Length>20)name=name[..20];var item=new CharacterSkin{Id=id,Name=name.Length==0?"我的形象":name,Tag="我的形象 · 弹跳与星光",Effect="stars",Color=0x8DCBB8,File=id+".png",Custom=true};
  var updated=Customs.Append(item).ToList();Save(side==Species.Ant?id:Selected,side==Species.Roach?id:Left,updated);Customs=updated;if(side==Species.Ant)Selected=id;else Left=id;return item;
 }
 public void Perform(World world,IEnumerable<int>? ids=null,Species side=Species.Ant){performedAt=world.Clock;performers=(ids??world.Bugs.Where(b=>b.Species==side).Take(16).Select(b=>b.Id)).ToHashSet();}
 public double? Performing(int id,double clock){double t=(clock-performedAt)/1.6;return performers.Contains(id)&&t>=0&&t<1?t:null;}
 public void Observe(World world,V point){if(world.Tool!=Tool.Observe)return;var b=world.Bugs.Where(b=>world.BodyHit(b,point,6)).OrderByDescending(b=>b.P.Y).FirstOrDefault();if(b!=null)Perform(world,new[]{b.Id},b.Species);}
}

public static class CharacterArt {
 public static void Native(DrawingContext c,string id,Bug b,bool dead=false){if(id=="rat"){using var t=Art.Transform(c,sx:.52,sy:.52);Art.VisitorBody(c,new Invader{Id=b.Id,Kind=InvaderKind.Rat,Phase=dead?0:b.Phase,Health=100});}else{var shown=b.Copy();shown.Species=id=="roach"?Species.Roach:Species.Ant;Art.Bug(c,shown,dead?0:b.Phase,dead);}}

 public static void Draw(DrawingContext c,Bug b,double clock,bool dead=false) {
  var library=CharacterLibrary.Shared;var skin=library.Skin(b.Species);if(skin==null)return;
  if(new[]{"roach","ant","rat"}.Contains(skin.Id)){using var native=Art.Transform(c,angle:b.Angle,sx:dead?1.1:1,sy:dead?.55:1);Native(c,skin.Id,b,dead);return;}double? playful=library.Performing(b.Id,clock);
  bool eating=b.BitePulse>0;int pose=dead?0:b.AttackPose>0||playful.HasValue?3:eating?2:b.Walking&&Math.Sin(b.Phase)>0?1:0;
  var image=library.Image(skin.Id,pose);if(image==null)return;
  double bounce=dead?0:playful.HasValue?Math.Abs(Math.Sin(playful.Value*Math.PI*4))*5:b.Walking?Math.Abs(Math.Sin(b.Phase))*1.4:0;
  double bite=eating&&!dead?Math.Sin(b.BitePulse/.55*Math.PI)*.12:0,breath=dead?0:Math.Sin(clock*2+b.Id)*.016;
  bool flip=(Math.Cos(b.Angle)<0)!=(skin.FacesLeft??false);
  using var t=Art.Transform(c,0,-bounce,dead?.26:playful.HasValue?Math.Sin(clock*14+b.Id)*.13:b.Walking?Math.Sin(b.Phase)*.045:0,(flip?-1:1)*(dead?1.12:1+bite+breath),dead?.56:1-bite*.55+breath);
  double h=36,w=h*image.PixelWidth/image.PixelHeight,k=Math.Min(1,36/w);c.DrawImage(image,new Rect(-w*k/2,-h*k/2,w*k,h*k));
  if(dead)for(int n=0;n<3;n++)Star(c,new V((n-1)*7,-15-n%2*3),1.6,Art.Brush(skin.Color,.65));
  else if(playful.HasValue)Accent(c,skin.Effect,playful.Value,.52,skin.Color);
 }
 private static void Star(DrawingContext c,V p,double radius,Brush color){var path=new StreamGeometry();using(var g=path.Open()){for(int n=0;n<10;n++){double a=n*Math.PI/5-Math.PI/2,r=radius*(n%2==0?1:.42);var point=new Point(p.X+Math.Cos(a)*r,p.Y+Math.Sin(a)*r);if(n==0)g.BeginFigure(point,true,true);else g.LineTo(point,true,false);}}c.DrawGeometry(color,null,path);}
 public static void Accent(DrawingContext c,string effect,double t,double size,uint color){using var q=Art.Transform(c,sx:size,sy:size,opacity:Math.Max(0,1-t)*.9);var brush=Art.Brush(color);switch(effect){
  case "beam":Art.Line(c,Art.Brush(color,.35),8*(1-t)+1,new V(-20,0),new V(32+t*24,0));Art.Line(c,Brushes.White,1.5,new V(-20,0),new V(32+t*24,0));c.DrawEllipse(null,new Pen(brush,1),new Point(15+t*10,0),5,13+t*12);break;
  case "electric":foreach(int side in new[]{-1,1})Art.Line(c,brush,2.1,new V(-20,side*7),new V(-5,side*14),new V(3,side*3),new V(18,side*13),new V(34+t*15,side*2));break;
  case "bubbles":for(int n=0;n<6;n++){double a=n*2.4,r=3+n%3;c.DrawEllipse(null,new Pen(brush,1),new Point(Math.Cos(a)*(12+t*25),Math.Sin(a)*(12+t*25)-t*15),r,r);}break;
  case "calm":for(int n=0;n<3;n++){double r=10+n*9+t*12;c.DrawEllipse(null,new Pen(Art.Brush(color,.55),1),new Point(0,8),r,r*.3);}break;
  case "claw":for(int n=-1;n<=1;n++){double y=n*7;Art.Line(c,brush,1.7,new V(-15,y-12),new V(5,y),new V(18,y+5));}break;
  case "ram":for(int n=-1;n<=1;n++)Art.Line(c,brush,2,new V(-27-t*15,n*9),new V(0,n*9));c.DrawEllipse(null,new Pen(brush,2),new Point(10+t*12,0),7.5,17);break;
  case "bounce":double r1=13+t*26;c.DrawEllipse(null,new Pen(brush,2*(1-t)+.5),new Point(0,0),r1,r1*.65);for(int n=0;n<4;n++){double a=n*Math.PI/2;Star(c,new V(Math.Cos(a)*r1,Math.Sin(a)*r1),3,brush);}break;
  default:for(int n=0;n<6;n++){double a=n*2.4,r=11+t*25;Star(c,new V(Math.Cos(a)*r,Math.Sin(a)*r-t*8),2+n%3,brush);}break;
 }}
 public static bool Fight(DrawingContext c,Fight fight,World world){var attacker=world.Bugs.FirstOrDefault(b=>b.Id==fight.Attacker)??world.Corpses.FirstOrDefault(b=>b.Id==fight.Attacker);if(attacker==null)return false;var skin=CharacterLibrary.Shared.Skin(attacker.Species);if(skin==null||skin.Id=="roach"||skin.Id=="ant")return false;var p=fight.From+(fight.To-fight.From)*.62;using var q=Art.Transform(c,p.X,p.Y,Math.Atan2(fight.To.Y-fight.From.Y,fight.To.X-fight.From.X));Accent(c,skin.Effect,fight.Age/.55,fight.Size,skin.Color);return true;}
}

public sealed class CharacterGallery:Window {
 private readonly Host host;private readonly WrapPanel cards=new();private readonly TextBlock status=new();
 private readonly Button[] teams=new Button[2];private readonly Button import;public Species Side {get;private set;}=Species.Roach;
 public CharacterGallery(Host host) {
  this.host=host;Title="选择两队宠物 · 桌面有点脏";Width=700;Height=740;MinWidth=700;MinHeight=620;Background=Art.Cream;Foreground=Art.Forest;FontFamily=new FontFamily("Microsoft YaHei UI");Topmost=true;Resources.Add(typeof(Button),ControlPanel.ButtonStyle());
  var root=new DockPanel{Margin=new Thickness(24)};Content=root;
  var head=new StackPanel();head.Children.Add(new TextBlock{Text="今天，让谁对上谁？",FontSize=24,FontWeight=FontWeights.Bold});head.Children.Add(new TextBlock{Text="先选左队或右队，再挑角色；两边都能导入自己的图片。",FontSize=12,Foreground=Art.Muted,Margin=new Thickness(0,10,0,16)});
  var choices=new System.Windows.Controls.Primitives.UniformGrid{Columns=2};for(int n=0;n<2;n++){var side=(Species)n;var button=Button("",()=>FocusTeam(side));button.Height=64;teams[n]=button;choices.Children.Add(button);}head.Children.Add(choices);
  status.Margin=new Thickness(0,12,0,16);status.TextWrapping=TextWrapping.Wrap;status.Foreground=Art.Muted;head.Children.Add(status);DockPanel.SetDock(head,Dock.Top);root.Children.Add(head);
  var footer=new StackPanel();var buttons=new System.Windows.Controls.Primitives.UniformGrid{Columns=3};import=Button("",Import);buttons.Children.Add(import);buttons.Children.Add(Button("蟑螂 × 蚂蚁",()=>{try{CharacterLibrary.Shared.RestorePair();Apply();}catch(Exception e){status.Text=e.Message;}}));buttons.Children.Add(Button("这一队表演一下",()=>{if(!host.World.Bugs.Any(b=>b.Species==Side)){status.Text="这一队还没有成员，先放卵等待孵化。";return;}host.World.Paused=false;CharacterLibrary.Shared.Perform(host.World,side:Side);host.Panel.Refresh();status.Text=host.World.TeamName(Side)+"登场！观察工具点它，也会回应。";}));footer.Children.Add(buttons);footer.Children.Add(new TextBlock{Text="PNG透明图效果最好；也支持JPEG和GIF首帧，20MB以内。\n两队可选同款。图片只保存在本机；切换角色，原生态继续。\n投食、成长、产卵、外敌和喷药共用；选蟑螂的队伍可以展翅飞行。",TextWrapping=TextWrapping.Wrap,FontSize=11,Foreground=Art.Muted,Margin=new Thickness(3,12,3,0)});DockPanel.SetDock(footer,Dock.Bottom);root.Children.Add(footer);
  var scroll=new ScrollViewer{VerticalScrollBarVisibility=ScrollBarVisibility.Auto,HorizontalScrollBarVisibility=ScrollBarVisibility.Disabled,Content=cards,Margin=new Thickness(0,0,0,15)};root.Children.Add(scroll);Rebuild();
 }
 private static Button Button(string title,Action action){var button=new Button{Content=title};button.Click+=(_,_)=>action();return button;}
 public void FocusTeam(Species side){Side=side;Rebuild();}
 public void Rebuild(){var library=CharacterLibrary.Shared;cards.Children.Clear();foreach(var skin in library.All){var content=new StackPanel();content.Children.Add(new System.Windows.Controls.Image{Source=library.Image(skin.Id),Height=90,Width=120,Stretch=Stretch.Uniform});content.Children.Add(new TextBlock{Text=skin.Name,HorizontalAlignment=HorizontalAlignment.Center,FontSize=14,FontWeight=FontWeights.SemiBold});content.Children.Add(new TextBlock{Text=skin.Tag,TextAlignment=TextAlignment.Center,FontSize=9,Foreground=Art.Muted,Margin=new Thickness(0,7,0,0)});var button=new Button{Content=content,Width=148,Height=145,Margin=new Thickness(3),Padding=new Thickness(4),ToolTip=skin.Tag,Background=Art.Brush(skin.Id==library.Selection(Side)?0xDCE9DFu:0xEDEDE4u)};System.Windows.Automation.AutomationProperties.SetName(button,(Side==Species.Roach?"左队换成":"右队换成")+skin.Name);button.Click+=(_,_)=>Select(skin.Id);cards.Children.Add(button);}
  for(int n=0;n<2;n++){var side=(Species)n;var name=library.Name(side);if(name.Length>14)name=name[..14];teams[n].Content=(n==0?"左队 · ":"右队 · ")+name+"\n"+(Side==side?"正在选择 · 从下方图库挑选":"点这里，更换这一队");teams[n].Background=Side==side?Art.Forest:Art.Brush(0xE8E9DF);teams[n].Foreground=Side==side?Art.Cream:Art.Forest;}
  import.Content=Side==Species.Roach?"＋ 给左队导入图片":"＋ 给右队导入图片";status.Text="正在选择："+host.World.TeamName(Side)+" · "+library.All.Count()+"款可选";
 }
 private void Apply(){CharacterLibrary.Shared.Apply(host.World);host.Panel.Refresh();host.Overlay.Canvas.InvalidateVisual();Rebuild();}
 private void Select(string id){try{CharacterLibrary.Shared.Select(id,Side);Apply();}catch(Exception e){status.Text=e.Message;}}
 private void Import(){var side=Side;var dialog=new OpenFileDialog{Title=side==Species.Roach?"给左队选择图片":"给右队选择图片",Filter="图片|*.png;*.jpg;*.jpeg;*.gif",Multiselect=false};if(dialog.ShowDialog(this)!=true)return;try{CharacterLibrary.Shared.Import(dialog.FileName,side);Apply();}catch(Exception e){status.Text="导入失败："+e.Message;}}
}
