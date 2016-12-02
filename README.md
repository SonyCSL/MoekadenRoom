# MoekadenRoom - An ECHONET Lite Emulator
エアコン、照明、電動ブラインド、電子錠、温度計の合計5種類の機器オブジェクトが含まれています。
Processingで作られています。
![](misc/MoekadenRoomCap.png)
##Updates
2016/12/2 <a href="https://github.com/issekiamp" target="_blank">一石アンプさん</a>のおかげでProcessing3に対応しました。  
2015/12/25 適当ですがスマートメーターオブジェクトを加えました。</font></p>  

# Download executables
以下からお好きなものを落として使ってください。Win64以外はJavaが必要だと思います。また、librariesフォルダ内にOpenECHO for ProcessingとControlP5が必要です。OpenECHOは<a href="https://github.com/SonyCSL/OpenECHO/tree/master/Processing/libraries" target="_blank">こちらから</a>落としてください。<a href="http://www.sojamo.de/libraries/controlP5/" target="_blank">ControlP5</a>はv2.2.5で確認しました。

+ <a href="misc/application.windows64.zip?raw=true" target="_blank">Win64bit版+Java Runtime</a>
+ <a href="misc/application.windows32.zip?raw=true" target="_blank">Win32bit版</a>
+ <a href="misc/application.linux-armv6hf.zip?raw=true" target="_blank">Linuxarmv6hf版</a>
+ <a href="misc/application.linux64.zip?raw=true" target="_blank">Linux64bit版</a>
+ <a href="misc/application.linux32.zip?raw=true" target="_blank">Linux32bit版</a>

※Mac版はExportできなかったためありません。ごめんなさい。

※ソースコードのライセンスは<a href="http://sourceforge.jp/projects/opensource/wiki/licenses%2FMIT_license" target="_blank">MITライセンス</a>にします。ただし、画像はそのまま二次利用しないでください。

※中で使っている<a href="https://github.com/SonyCSL/OpenECHO" title="OpenECHO site" target="_blank">OpenECHO</a>もMITです。<a href="http://www.sojamo.de/libraries/controlP5/" title="Control P5 page" target="_blank">ControlP5</a>はLGPLです。

# 使用方法
+ このアプリは2種類の入力を受け付けます。1. ECHONET Liteネットワークからの入力、2. ユーザーのマウスによる入力です。
+ 温度センサーについては、本来外部入力によりその値を変更することはできませんが、エミュレータなので、ユーザーがマウスで温度計の右にあるスライダを動かすと値を変更できるようにしました。
+ 本プログラムが走っているのにECHONET Liteネットワークから機器オブジェクトが見えない場合、ウィルス対策ソフトやファイアーウォールが悪さをしているかもしれません。ECHONET LiteはUDPのポートを開けて使いますのでそれを防がれてしまうと通信できません。トラブルの時はファイアーウォールを切る必要があるかもしれません。ただし、もちろんその間は外部からの攻撃に対して脆弱になりますので、自己責任でお願いします。
+ １つのPCで２つ以上立ち上げてはいけません。本エミュレータは「ノード」を一つ作り、その中に機器オブジェクトを4つ入れるようになっています。IPv4で実装されたECHONET Liteでは、一つのIPアドレスに対してノードは１つでないといけないという制約があります。1つのPCで二つエミュレータを立ち上げると、ノードが2つになってしまうわけです。
+ 萌家電の背景画像を使っただけなので、萌えキャラは出てきません

# 主な実装済みオブジェクト・プロパティ
<table>
<tr>
<th>オブジェクト名(EOJ)</th>
<th>プロパティ(EPC)</th>
<th>Values(EDT)<br />(太字は初期値)</th>
</tr>
<tr>
<td rowspan=3>Home Air Conditioner<br />0x0130</td>
<td>電源<br />0x80</td>
<td><b>[0x31]:Off</b><br />[0x30]:On</td>
</tr>
<tr>
<td>動作モード<br />0xb0</td>
<td>[0x41]:Auto<br /><b>[0x42]:Cool</b><br />[0x43]:Heat<br />[0x44]:Dry<br />[0x45]:Wind</td>
</tr>
<tr>
<td>設定温度<br />0xb3</td>
<td>1byteで符号付設定温度。<br /><b>Default=[20](=20℃)</b></td>
</tr>
<tr>
<td>照明オブジェクト<br />0x0290</td>
<td>電源<br />0x80</td>
<td><b>[0x31]:Off</b><br />[0x30]:On</td>
</tr>
<tr>
<td>電動ブラインドオブジェクト<br />0x0260</td>
<td>開閉状態<br />0xe0</td>
<td><b>[0x41]:Open</b><br />[0x42]:Close</td>
</tr>
<tr>
<td>電子錠オブジェクト<br />0x026F</td>
<td>施錠状態<br />0xe0</td>
<td><b>[0x41]:Locked</b><br />[0x42]:Unlocked</td>
</tr>
<tr>
<td>温度計オブジェクト<br />0x0011</td>
<td>温度<br />0xe0</td>
<td>Big endian 2byteで<br />符号付温度を0.1℃<br />単位で表す<br /><b>(Default [0,220]<br /> = 22.0℃)</b></td>
</tr>
</table>

# Contributors
[Shigeru Owada](https://github.com/sowd)  
[Fumiaki Tokuhisa](https://github.com/tokuhisa)  
[Issekiamp san](https://github.com/issekiamp)  

Project page: http://kadecot.net/blog/1479/  (Japanese)
