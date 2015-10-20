import java.io.IOException;
import processing.net.*;
import controlP5.*;

import java.util.Iterator;

import com.sonycsl.echo.Echo;
import com.sonycsl.echo.EchoProperty;
import com.sonycsl.echo.node.EchoNode;
import com.sonycsl.echo.eoj.EchoObject;
import com.sonycsl.echo.eoj.profile.NodeProfile;
import com.sonycsl.echo.eoj.device.DeviceObject;

import com.sonycsl.echo.eoj.profile.NodeProfile;
import com.sonycsl.echo.eoj.device.airconditioner.HomeAirConditioner;
import com.sonycsl.echo.eoj.device.housingfacilities.GeneralLighting;
import com.sonycsl.echo.eoj.device.housingfacilities.ElectricallyOperatedShade;
import com.sonycsl.echo.eoj.device.housingfacilities.ElectricLock;
import com.sonycsl.echo.eoj.device.sensor.TemperatureSensor ;

//////////////////////////////
//////////////////////////////
//////////////////////////////
// JSONP server class
//////////////////////////////
//////////////////////////////
//////////////////////////////

class HTTPServer extends Server {
  public HTTPServer(PApplet c , int port , SoftAirconImpl aircon , SoftLightImpl light , SoftBlindImpl blind
   , SoftTempSensorImpl exTempSensor, SoftLockImpl lock){
   super( c,port ) ;

   devs.put( "HomeAirConditioner" , new DevInstance(aircon,"0x0130") ) ;
   aircon.setReceiver( new HomeAirConditioner.Receiver(){
     protected boolean onGetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onGetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(true,eoj, tid, esv, property, success) ;
       return ret ;
     }
     protected boolean onSetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onSetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(false,eoj, tid, esv, property, success) ;
       return ret ;
     }
   }) ;
   devs.put( "GeneralLighting" , new DevInstance(light,"0x0290") ) ;
   light.setReceiver( new GeneralLighting.Receiver(){
     protected boolean onGetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onGetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(true,eoj, tid, esv, property, success) ;
       return ret ;
     }
     protected boolean onSetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onSetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(false,eoj, tid, esv, property, success) ;
       return ret ;
     }
   }) ;
   devs.put( "ElectricallyOperatedShade" , new DevInstance(blind,"0x0260") ) ;
   blind.setReceiver( new ElectricallyOperatedShade.Receiver(){
     protected boolean onGetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onGetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(true,eoj, tid, esv, property, success) ;
       return ret ;
     }
     protected boolean onSetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onSetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(false,eoj, tid, esv, property, success) ;
       return ret ;
     }
   }) ;
   devs.put( "TemperatureSensor" , new DevInstance(exTempSensor,"0x0011") ) ;
   exTempSensor.setReceiver( new TemperatureSensor.Receiver(){
     protected boolean onGetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onGetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(true,eoj, tid, esv, property, success) ;
       return ret ;
     }
     protected boolean onSetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onSetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(false,eoj, tid, esv, property, success) ;
       return ret ;
     }
   }) ;
   devs.put( "ElectricLock" , new DevInstance(lock,"0x026f") ) ;
   lock.setReceiver( new ElectricLock.Receiver(){
     protected boolean onGetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onGetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(true,eoj, tid, esv, property, success) ;
       return ret ;
     }
     protected boolean onSetProperty(EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success){
       boolean ret = super.onSetProperty(eoj, tid, esv, property, success);
       HTTPServer.this.onAccess(false,eoj, tid, esv, property, success) ;
       return ret ;
     }
   }) ;
   }
  
  class DevInstance {
    DevInstance(DeviceObject d,String cid){this.d = d ; this.clsid = cid ; }
    public DeviceObject d ;
    public String clsid ;
  } ;

  public HashMap<String,DevInstance> devs = new HashMap<String,DevInstance>() ;

  class WaitObj {
    public WaitObj(Client c,String jcb,String nn){this.c=c;this.jsoncallback=jcb;nickname=nn;}
    Client c ;
    String jsoncallback , nickname;
  }
  public HashMap<String,WaitObj> waitList = new HashMap<String,WaitObj>() ;

  public void update(){
      Client c ;
      if( (c = this.available()) == null )
        return ;

      final int lf = 10;
      String st = c.readStringUntil(lf) ;
      if( st == null || !st.startsWith("GET") ) return ;
      
      String pathall = st.split(" ")[1].replace("%20"," ").replace("%22","\"") ;
      String[] args = pathall.substring(pathall.indexOf("?")+1).split("&") ;
      
      HashMap<String,String> m = new HashMap<String,String>() ; 
      for( String term : args ){
        String[] lr = term.split("=");
        if( lr.length < 2 ) continue ;
        //println(term);
        m.put(lr[0],lr[1]) ;
      }
      
      String func ;
      if( (func = m.get("method")) != null ){
        if( func.equals("list") ){
          c.write( getListReply(m) ) ;
          c.stop() ;
        } else {
          reqAccess( func.equals("get") , m,c) ;
        }
      }
  }
  protected String getReplySub_GetHeader(int content_length){
    return "HTTP/1.1 200 OK\nConnection: close\nContent-Length: "+content_length+"\n"
      + "Content-Type: application/json\n\n" ;
      //+ "Content-Type: application/json\nEtag: \"0f3ac231df2644fcac1cc9705915923e\"\n\n" ; // Etag unnecessary?
  }
  protected String getListReply( HashMap<String,String> args ){
    String ret = "{\"result\":[\n" ;
    String[] etype = {
      "{\"active\":true,\"protocol\":\"ECHONET Lite\",\"deviceName\":\""
      ,"\",\"nickname\":\""
      ,"\",\"option\":{},\"deviceType\":\""
      ,"\"}\n"
    } ;
    boolean bFirst = true ;
    for (Iterator<String> it = devs.keySet().iterator(); it.hasNext(); ) {
      String Key = it.next();
      DevInstance Value = devs.get(Key) ;
      if( !bFirst ) ret += "," ; bFirst = false ;
      ret += etype[0]+Key+etype[1]+Key+etype[2]+Value.clsid+etype[3] ;
    }

    ret +="]}" ;

    String jcb = args.get("jsoncallback") ;
    if( jcb == null ) jcb = args.get("callback") ;
    if( jcb != null ) ret = jcb+"("+ret+")" ;

    return getReplySub_GetHeader( ret.length() ) + ret ;
  }
  protected void reqAccess( boolean bGet , HashMap<String,String> args , Client c ){
    String argsStr ;

    if( (argsStr = args.get("params")) != null ){
      String arg_json = "{\"data\":"+argsStr+"}" ;
      //JSONArray params = JSONArray.getJSONArray(argsStr) ;
      JSONArray params = JSONArray.parse(argsStr);
      //JSONArray params = (new JSONObject("{\"data\":"+argsStr+"}")).getJSONArray("data") ;
      //String[] prms = argsStr.replace("[\\[\\]\"]","").split(",") ;
      //String[] prms = argsStr.replace("[","").replace("]","").replace("\"","").split(",") ;
      //println(prms) ;
      
      String nickname = params.getString(0) ;
      if( !devs.containsKey(nickname) ) return ;
      DeviceObject d = devs.get(nickname).d ;
      //DeviceObject d = (devs.containsKey(prms[0])?devs.get(prms[0]).d:null) ;

      //if( d != null ){
        //boolean bGet = (prms.length <= 2) ;
        String jcb = args.get("jsoncallback") ;
        if( jcb == null ) jcb = args.get("callback") ;
        waitList.put( (bGet?"G":"S")+d.toString() , new WaitObj(c,jcb,nickname) ) ;
        try {
          if( bGet ){ // Get
            DeviceObject.Getter g = d.get() ;
            for( int pi=1;pi<params.size();++pi ){
              g = g.reqGetProperty( Integer.decode(params.getString(pi)).byteValue() ) ;
            }
            g.send() ;
            //d.get().reqGetProperty( Integer.decode(prms[1]).byteValue() ).send() ;
            println("reqGet : "+d.toString()) ;
          } else {  // Set
            DeviceObject.Setter s = d.set() ;
            for( int pi=1;pi<params.size();++pi ){
              JSONArray ja = params.getJSONArray(pi) ;
              JSONArray ja_prm = ja.getJSONArray(1) ;
              byte[] prm = new byte[ja_prm.size()] ;
              for( int pii = 0 ; pii < prm.length ; ++pii )
                 prm[pii] = Integer.decode(ja_prm.getString(pii)).byteValue() ; 
              s = s.reqSetProperty(
                Integer.decode(ja.getString(0)).byteValue() , prm ) ;
                //,Integer.decode(ja.getString(1)).byteValue() ) ;
            }
            s.send() ;
            
            //byte[] prms_real = new byte[prms.length-2] ;
            //for( int pi=2;pi<prms.length;++pi )  prms_real[pi-2] = Integer.decode(prms[pi]).byteValue() ;
            //d.set().reqSetProperty( Integer.decode(prms[1]).byteValue() , prms_real ).send() ;
            println("reqSet : "+d.toString()) ;
          }
        } catch (IOException e){ e.printStackTrace(); }
      //}
    }
  }
  protected void onAccess( boolean bGet , EchoObject eoj, short tid, byte esv,EchoProperty property, boolean success ){
         println("onAccess : "+eoj.toString()) ;
         WaitObj wo = waitList.get((bGet?"G":"S")+eoj.toString()) ;
         if( wo==null ) return ;
         waitList.remove((bGet?"G":"S")+eoj.toString()) ;

        String edtstr = "" ;
        if( property.edt != null ){
          for( int ei=0;ei<property.edt.length;++ei ){
            if( ei != 0 ) edtstr += "," ;
            //edtstr += String.format("0x%x",property.edt[ei]) ;
            edtstr += property.edt[ei] ;
          }
        }

         String ret = String.format( "{\"result\":{\"nickname\":\"%s\",\"property\":[{\"value\":[%s],\"success\":%s,\"name\":\"0x%x\"}]}}"
           //
           ,wo.nickname
           ,edtstr
           ,(success?"true":"false")
           ,property.epc ) ;

         if( wo.jsoncallback != null )   ret = wo.jsoncallback+"("+ret+")" ;
          ret = getReplySub_GetHeader( ret.length() ) + ret ;

          println("on"+(bGet?"Get":"Set")+" : " + ret) ;
          wo.c.write(ret) ;

         wo.c.stop() ;
  }
} ;

HTTPServer httpserv ;






public class MyNodeProfile extends NodeProfile {
  byte[] mManufactureCode = {0,0,0};
  byte[] mStatus = {0x30};
  byte[] mVersion = {1,1,1,0};
  byte[] mIdNumber = {(byte)0xFE,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
  byte[] mUniqueId = {0,0};
  protected byte[] getManufacturerCode() {return mManufactureCode;}
  protected byte[] getOperatingStatus() {  return mStatus;  }
  protected byte[] getVersionInformation() {return mVersion;}
  protected byte[] getIdentificationNumber() {return mIdNumber;}
  protected boolean setUniqueIdentifierData(byte[] edt) {
    if((edt[0] & 0x40) != 0x40)   return false;
    mUniqueId[0] = (byte)((edt[0] & (byte)0x7F) | (mUniqueId[0] & 0x80));
    mUniqueId[1] = edt[1];
    return true;
  }
  protected byte[] getUniqueIdentifierData() {return mUniqueId;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}
}

//////////////////////////////
//////////////////////////////
//////////////////////////////
// Airconditoner class
//////////////////////////////
//////////////////////////////
//////////////////////////////
int pw,mode,temp ;
int ps, af;
public class SoftAirconImpl extends HomeAirConditioner {
  public byte[] mStatus = {0x31};// 初期の電源状態はOFFだと仮定します。
  public byte[] mMode = {0x41};  // 初期モードは自動モードと仮定します。
  public byte[] mTemperature = {20}; // 初期の設定温度は20度と仮定します。
  public byte[] mPowerSaving = {0x42}; // 初期の節電動作設定は通常動作中と仮定します。
  public byte[] mAirFlow = {0x41}; // 初期の風量設定は風量自動設定と仮定します。

  //////////////////////////////////
  // 以下、必須プロパティの適当な実装です。
  // 本当はもっときちんと実装しなければいけなさそうです。
  //////////////////////////////////
  byte[] mLocation = {0x00};
  byte[] mVersion = {0x01, 0x01, 0x61, 0x00};
  byte[] mFaultStatus = {0x42};
  byte[] mManufacturerCode = {0,0,0};

  protected boolean setInstallationLocation(byte[] edt) {return true;}
  protected byte[] getInstallationLocation() {return mLocation;}
  protected byte[] getStandardVersionInformation() {return mVersion;}
  protected byte[] getFaultStatus() {  return mFaultStatus;}
  protected byte[] getManufacturerCode() {return mManufacturerCode;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}

  protected void setupPropertyMaps() {
    super.setupPropertyMaps();
	
	addGetProperty(EPC_POWER_SAVING_OPERATION_SETTING);
	addSetProperty(EPC_POWER_SAVING_OPERATION_SETTING);
	addGetProperty(EPC_AIR_FLOW_RATE_SETTING);
	addSetProperty(EPC_AIR_FLOW_RATE_SETTING);
	addGetProperty(EPC_MEASURED_VALUE_OF_ROOM_TEMPERATURE);
  }

  // 以下はわりかし真面目な実装です。
  // 電源のON/OFF操作です。
  protected boolean setOperationStatus(byte[] edt) {
    mStatus[0] = edt[0];
    pw = edt[0]-0x30 ;
    try {
      inform().reqInformOperationStatus().send();
    } catch (IOException e) { e.printStackTrace();}
    setupImage() ;
    return true;
  }
  // 現在の電源状態を問われた時の応答です。
  protected byte[] getOperationStatus() { return mStatus; }

  // より操作しやすい関数を作ってみました。
  // ※HomeAirConditionerからのオーバーライドではありません。
  public void setOperationStatusBoolean(boolean is_on){
    // 中でSetterを使って機器を制御します。ここで、直接setOperationStatusを
    // 呼びだしてはいけません。
    try{
      if(is_on){
        this.set().reqSetOperationStatus(new byte[]{(byte)0x30}).send();
      }else{
        this.set().reqSetOperationStatus(new byte[]{(byte)0x31}).send();
      }
    }catch (IOException e){
      e.printStackTrace();
    }
  }

  // 動作モードの変更です。
  protected boolean setOperationModeSetting(byte[] edt) {
    mMode[0] = edt[0];
    mode = edt[0] - 0x41 ;
    try {
      inform().reqInformOperationModeSetting().send();
    } catch (IOException e) { e.printStackTrace();}
    setupImage() ;
    
    return true;
  }

  protected byte[] getOperationModeSetting() {return mMode;}

  // より操作しやすい関数を作ってみました。
  // ※HomeAirConditionerからのオーバーライドではありません。
  public void setOperationModeSettingInt(int mode) {
    byte toSend = (byte)(0x41+mode);
    try{
      this.set().reqSetOperationModeSetting(new byte[]{toSend}).send();
    } catch (IOException e){
      e.printStackTrace();
    }
  }


  // 温度の変更です
  protected boolean setSetTemperatureValue(byte[] edt) {
    temp = mTemperature[0] = edt[0];
    setupImage() ;
    return true;
  }

  protected byte[] getSetTemperatureValue() {  return mTemperature;}

  // より操作しやすい関数を作ってみました。
  // ※HomeAirConditionerからのオーバーライドではありません。
  protected void setTemperatureValueInt(int temp) {
    try{
      this.set().reqSetSetTemperatureValue(new byte[]{(byte)temp}).send();
    } catch(IOException e){
      e.printStackTrace();
    }
  }


  /**
   * This property indicates whether the device is operating in power-saving mode.<br>
   * <br>
   * Operating in power-saving mode =0x41<br>
   * Operating in normal operation mode =0x42<br>
   * <br>
   * Data Type : unsigned char<br>
   * Data Size(Byte) : 1<br>
   * <br>
   * AccessRule<br>
   * Announce : undefined<br>
   * Set : optional<br>
   * Get : optional<br>
   */
  protected boolean setPowerSavingOperationSetting(byte[] edt) {
    mPowerSaving[0] = edt[0];
    ps = edt[0] - 0x41;
    try {
      inform().reqInformPowerSavingOperationSetting().send();
    } catch (IOException e) { e.printStackTrace(); }
    return true;
  }

  /**
   * This property indicates whether the device is operating in power-saving mode.<br>
   * <br>
   * Operating in power-saving mode =0x41<br>
   * Operating in normal operation mode =0x42<br>
   * <br>
   * Data Type : unsigned char<br>
   * Data Size(Byte) : 1<br>
   * <br>
   * AccessRule<br>
   * Announce : undefined<br>
   * Set : optional<br>
   * Get : optional<br>
   */
  protected byte[] getPowerSavingOperationSetting() { return mPowerSaving; }

  /**
   * Property name : Measured value of room temperature<br>
   * <br>
   * EPC : 0xBB<br>
   * <br>
   * Contents of property :<br>
   * Measured value of room temperature<br>
   * <br>
   * Value range (decimal notation) :<br>
   * 0x80.0x7D (-127.125.C)<br>
   * <br>
   * Data type : signed char<br>
   * <br>
   * Data size : 1 byte<br>
   * <br>
   * Unit : .C<br>
   * <br>
   * Access rule :<br>
   * Announce - undefined<br>
   * Set - undefined<br>
   * Get - optional<br>
   */
  protected byte[] getMeasuredValueOfRoomTemperature() {
    byte[] rt = { 0x00 };
    rt[0] = (byte)(room_temp_x10/10);
	return rt;
  }

  /**
   * Property name : Air flow rate setting<br>
   * <br>
   * EPC : 0xA0<br>
   * <br>
   * Contents of property :<br>
   * Used to specify the air flow rate or use the function to automatically control the air flow rate, and to acquire the current setting. The air flow rate shall be selected from among the 8 predefined levels.<br>
   * <br>
   * Value range (decimal notation) :<br>
   * Automatic air flow rate control function used = 0x41<br>
   * Air flow rate = 0x31.0x38<br>
   * <br>
   * Data type : unsigned char<br>
   * <br>
   * Data size : 1 byte<br>
   * <br>
   * Unit : -<br>
   * <br>
   * Access rule :<br>
   * Announce - undefined<br>
   * Set - optional<br>
   * Get - optional<br>
   */
  protected boolean setAirFlowRateSetting(byte[] edt) {
    mAirFlow[0] = edt[0];
    af = edt[0] - 0x31;
    try {
      inform().reqInformAirFlowRateSetting().send();
    } catch (IOException e) { e.printStackTrace(); }
    return true;
  }

  /**
   * Property name : Air flow rate setting<br>
   * <br>
   * EPC : 0xA0<br>
   * <br>
   * Contents of property :<br>
   * Used to specify the air flow rate or use the function to automatically control the air flow rate, and to acquire the current setting. The air flow rate shall be selected from among the 8 predefined levels.<br>
   * <br>
   * Value range (decimal notation) :<br>
   * Automatic air flow rate control function used = 0x41<br>
   * Air flow rate = 0x31.0x38<br>
   * <br>
   * Data type : unsigned char<br>
   * <br>
   * Data size : 1 byte<br>
   * <br>
   * Unit : -<br>
   * <br>
   * Access rule :<br>
   * Announce - undefined<br>
   * Set - optional<br>
   * Get - optional<br>
   */
  protected byte[] getAirFlowRateSetting() { return mAirFlow; }

  // 表示を入れ替える関数です
  protected void setupImage(){
    if( pw==0 ){   // on
      switchLayer( "AirconPower","On" ) ;
      switch(mode){
        case 0 : case 1 :          // 0x41:Auto, 0x42:Cool 
          switchLayer( "AirconWind","Cool" ) ; break ;
        case 2 :                   // 0x43:Heat
          switchLayer( "AirconWind","Hot" ) ; break ;
        case 3 :                   // 0x44:Dry
          switchLayer( "AirconWind","Dry" ) ; break ;
        case 4 : case 5 :          // 0x45:Wind, 0x46:Others
          switchLayer( "AirconWind","Wind" ) ; break ;
      }
    } else {       // off
      switchLayer( "AirconPower","Off" ) ;
      switchLayer( "AirconWind",-1 ) ;
    }
  }


}

SoftAirconImpl aircon ;





//////////////////////////////
//////////////////////////////
//////////////////////////////
// Light class
//////////////////////////////
//////////////////////////////
//////////////////////////////
int light_pw ;
public class SoftLightImpl extends GeneralLighting {
  public byte[] mStatus = {0x31};// 初期の電源状態はOFFだと仮定します。

  //////////////////////////////////
  // 以下、必須プロパティの適当な実装です。
  // 本当はもっときちんと実装しなければいけなさそうです。
  //////////////////////////////////

  byte[] mLocation = {0x00};
  byte[] mVersion = {0x01, 0x01, 0x61, 0x00};
  byte[] mFaultStatus = {0x42};
  byte[] mManufacturerCode = {0,0,0};

  protected boolean setInstallationLocation(byte[] edt) {return true;}
  protected byte[] getInstallationLocation() {return mLocation;}
  protected byte[] getStandardVersionInformation() {return mVersion;}
  protected byte[] getFaultStatus() {  return mFaultStatus;}
  protected byte[] getManufacturerCode() {return mManufacturerCode;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}

  // 電源のON/OFF操作です。
  protected boolean setOperationStatus(byte[] edt) {
    mStatus[0] = edt[0];
    light_pw = edt[0]-0x30 ;
    try {
      inform().reqInformOperationStatus().send();
    } catch (IOException e) { e.printStackTrace();}
    setupImage() ;
    return true;
  }
  
  // 現在の電源状態を問われた時の応答です
  protected byte[] getOperationStatus() {
    return mStatus;
  }

  // より操作しやすい関数を作ってみました。
  // ※GeneralLightingからのオーバーライドではありません。
  public void setOperationStatusBoolean(boolean is_on){
    // 中でSetterを使って機器を制御します。ここで、直接setOperationStatusを
    // 呼びだしてはいけません。
    try{
      if(is_on){
        this.set().reqSetOperationStatus(new byte[]{(byte)0x30}).send();
      }else{
        this.set().reqSetOperationStatus(new byte[]{(byte)0x31}).send();
      }
    }catch (IOException e){
      e.printStackTrace();
    }
  }
  
  protected boolean setLightingModeSetting(byte[] edt) { return false; }
  protected byte[] getLightingModeSetting(){
    return null;
  }

  // 表示を入れ替える関数です
  protected void setupImage(){
    switchLayer( "LightPower",light_pw==0?"On":"Off" ) ;
  }
}

SoftLightImpl light ;





//////////////////////////////
//////////////////////////////
//////////////////////////////
// Blind class
//////////////////////////////
//////////////////////////////
//////////////////////////////
int blind_open ;
public class SoftBlindImpl extends ElectricallyOperatedShade {
  public byte[] mStatus = {0x30};// 電源状態は常にONだと仮定します。
  public byte[] mOpen = {0x41};  // 初期の開閉状態は「開」だと仮定します。(閉は0x42)

  //////////////////////////////////
  // 以下、必須プロパティの適当な実装です。
  // 本当はもっときちんと実装しなければいけなさそうです。
  //////////////////////////////////

  byte[] mLocation = {0x00};
  byte[] mVersion = {0x01, 0x01, 0x61, 0x00};
  byte[] mFaultStatus = {0x42};
  byte[] mManufacturerCode = {0,0,0};

  protected boolean setInstallationLocation(byte[] edt) {return true;}
  protected byte[] getInstallationLocation() {return mLocation;}
  protected byte[] getStandardVersionInformation() {return mVersion;}
  protected byte[] getFaultStatus() {  return mFaultStatus;}
  protected byte[] getManufacturerCode() {return mManufacturerCode;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}

  // 電源のON/OFF操作ですが、実際には使われないという仮定です。
  protected boolean setOperationStatus(byte[] edt) {
    mStatus[0] = edt[0];
    try {
      inform().reqInformOperationStatus().send();
    } catch (IOException e) { e.printStackTrace();}
    return true;
  }
  protected byte[] getOperationStatus() { return mStatus; }

  // 開閉状態の変更です。
  protected boolean setOpenCloseSetting(byte[] edt) {
    mOpen[0] = edt[0];
    blind_open = edt[0] - 0x41 ;
    try {
      inform().reqInformOpenCloseSetting().send();
    } catch (IOException e) { e.printStackTrace();}
    setupImage() ;
    
    return true;
  }

  protected byte[] getOpenCloseSetting() {return mOpen;}

  // より操作しやすい関数を作ってみました。
  // ※ElectricallyOperatedShadeからのオーバーライドではありません。
  public void setOpenCloseSettingBoolean(boolean is_open){
    try{
      if(is_open){
        this.set().reqSetOpenCloseSetting(new byte[]{(byte)0x41}).send();
      }else{
        this.set().reqSetOpenCloseSetting(new byte[]{(byte)0x42}).send();
      }
    }catch (IOException e){
      e.printStackTrace();
    }
  }
  // abstractメソッドの仕方ない実装です
  protected boolean setOpenCloseSetting2(byte[] edt) {return true;}
  protected byte[] getOpenCloseSetting2() {return mOpen;}

  protected boolean setDegreeOfOpeniNgLevel(byte[] edt) {return false;}
  protected byte[] getDegreeOfOpeniNgLevel() {return null;}
  //protected boolean setOpenCloseSetting(byte[] edt) {return false;}
  //protected byte[] getOpenCloseSetting() {return null;}
  //protected byte[] getOpenCloseSetting() {  return null;}

  // 表示を入れ替える関数です
  protected void setupImage(){
    switchLayer( "CurtainState",blind_open==0?"Open":"Close" ) ;
  }
}

SoftBlindImpl blind ;







//////////////////////////////
//////////////////////////////
//////////////////////////////
// TempSensor class
//////////////////////////////
//////////////////////////////
//////////////////////////////
int room_temp_x10 ;
public class SoftTempSensorImpl extends TemperatureSensor {
  public byte[] mStatus = {0x30};// 電源状態は常にONだと仮定します。
  public byte[] mTemp = {0,(byte)220};  // 初期温度は22度だと仮定します。

  byte[] mLocation = {0x00};
  byte[] mVersion = {0x01, 0x01, 0x61, 0x00};
  byte[] mFaultStatus = {0x42};
  byte[] mManufacturerCode = {0,0,0};

  protected boolean setInstallationLocation(byte[] edt) {return true;}
  protected byte[] getInstallationLocation() {return mLocation;}
  protected byte[] getStandardVersionInformation() {return mVersion;}
  protected byte[] getFaultStatus() {  return mFaultStatus;}
  protected byte[] getManufacturerCode() {return mManufacturerCode;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}

  // 電源のON/OFF操作ですが、実際には使われないという仮定です。
  protected boolean setOperationStatus(byte[] edt) {
    mStatus[0] = edt[0];
    try {
      inform().reqInformOperationStatus().send();
    } catch (IOException e) { e.printStackTrace();}
    return true;
  }
  protected byte[] getOperationStatus() { return mStatus; }

  protected byte[] getMeasuredTemperatureValue() {return mTemp;}

  // 温度変更用関数です。本来温度センサー値は外から変更できないので、
  // エミュレータ専用の機能です。
  // ※TemperatureSensorからのオーバーライドではありません。
  public void setTemp(int temp_x10){
    room_temp_x10 = temp_x10 ;
    if( temp_x10<0 )  temp_x10 = 0x10000+temp_x10 ;
    mTemp[0] = (byte)(temp_x10/256) ;
    mTemp[1] = (byte)(temp_x10%256) ;
  }
}

SoftTempSensorImpl exTempSensor ;






//////////////////////////////
//////////////////////////////
//////////////////////////////
// Lock class
//////////////////////////////
//////////////////////////////
//////////////////////////////
int lock_locked ;
public class SoftLockImpl extends ElectricLock {
  public byte[] mStatus = {0x30};// Always on
  public byte[] mLock = {0x41};  // Locked(0x42:Unlocked)

  byte[] mLocation = {0x00};
  byte[] mVersion = {0x01, 0x01, 0x61, 0x00};
  byte[] mFaultStatus = {0x42};
  byte[] mManufacturerCode = {0,0,0};

  protected boolean setInstallationLocation(byte[] edt) {return true;}
  protected byte[] getInstallationLocation() {return mLocation;}
  protected byte[] getStandardVersionInformation() {return mVersion;}
  protected byte[] getFaultStatus() {  return mFaultStatus;}
  protected byte[] getManufacturerCode() {return mManufacturerCode;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}

  protected byte[] getOperationStatus() { return mStatus; }

  // 開閉状態の変更です。
  protected boolean setLockSetting1(byte[] edt) {
    mLock[0] = edt[0];
    lock_locked = 0x42-edt[0] ;
    try {
      inform().reqInformLockSetting1().send();
    } catch (IOException e) { e.printStackTrace();}
    setupImage() ;
    
    return true;
  }

  protected byte[] getLockSetting1() {return mLock;}

  // より操作しやすい関数を作ってみました。
  // ※ElectricallyOperatedShadeからのオーバーライドではありません。
  public void setLockSetting1Boolean(boolean bLock){
    try{
      if(bLock){
        this.set().reqSetLockSetting1(new byte[]{(byte)0x41}).send();
      }else{
        this.set().reqSetLockSetting1(new byte[]{(byte)0x42}).send();
      }
    }catch (IOException e){
      e.printStackTrace();
    }
  }

  // 表示を入れ替える関数です
  protected void setupImage(){
    //switchLayer( "CurtainState",blind_open==0?"Open":"Close" ) ;
  }
}

SoftLockImpl lock ;








ControlP5 cp5;

JSONObject backImgJSON ;
String backImgPath = "_f_Back/" ;

HashMap<Integer,PImage> imgIdToPImageMap ;
HashMap<String,JSONObject> imgSwitchLayers = new HashMap<String,JSONObject>() ;
HashMap<String,Integer> imgTypeMap = new HashMap<String,Integer>() ;
final int STACKLAYERS = 0 , ACCUMLAYERS = 1 , SWITCHLAYERS = 2 , ANIMLAYERS = 3
  , GAMELAYERS = 4 , IMAGELAYER = 5 , AREALAYER = 6 ;



String[] pwBtns = {"On","Off"} ;
String[] modeBtns = {"Auto","Cool","Heat","Dry","Wind"} ;
String[] tempBtns = {"Up","Down"} ;
String[] lightBtns = {"LightOn","LightOff"} ;
String[] blindBtns = {"CurtainOpen","CurtainClose"} ;
String[] lockBtns = {"LockKey","UnlockKey"} ;

void setup() {
  backImgJSON = loadJSONObject(backImgPath+"setup.json") ;

  size(backImgJSON.getInt("width"),backImgJSON.getInt("height"));

  // Setup imgTypeMap
  imgTypeMap.put("stacklayers",STACKLAYERS) ;    imgTypeMap.put("accumlayers",ACCUMLAYERS) ;
  imgTypeMap.put("switchlayers",SWITCHLAYERS) ;  imgTypeMap.put("animlayers",ANIMLAYERS) ;
  imgTypeMap.put("gamelayers",GAMELAYERS) ;      imgTypeMap.put("image",IMAGELAYER) ;
  imgTypeMap.put("area",AREALAYER) ;

  imgIdToPImageMap = new HashMap<Integer,PImage>() ;
  setupImages( backImgJSON ) ;
  
  cp5 = new ControlP5(this);
  // The background image must be the same size as the parameters
  // into the size() method. In this program, the size of the image
  // is 650 x 360 pixels.

  for( int pbi=0;pbi<pwBtns.length;++pbi )
    cp5.addButton(pwBtns[pbi]).setPosition(582+pbi*35,8).setSize(30,15) ;
  for( int mbi=0;mbi<modeBtns.length;++mbi )
    cp5.addButton(modeBtns[mbi]).setPosition(582+mbi*35,33).setSize(30,15) ;
  for( int ubi=0;ubi<tempBtns.length;++ubi )
    cp5.addButton(tempBtns[ubi]).setPosition(582+(ubi+3)*35,8).setSize(30,15) ;

  for( int li=0;li<lightBtns.length;++li )
    cp5.addButton(lightBtns[li]).setPosition(75,200+li*20).setSize(40,15) ;

  for( int li=0;li<blindBtns.length;++li )
    cp5.addButton(blindBtns[li]).setPosition(240,50+li*20).setSize(65,15) ;

  cp5.addSlider("RoomTempSlider").setPosition(193,50).setSize(5,50).setRange(-100,400)
    .setLabelVisible(false);//.setColorForeground(0xdceffa);

  for( int li=0;li<lockBtns.length;++li )
    cp5.addButton(lockBtns[li]).setPosition(780,400+li*20).setSize(55,15) ;

  // System.outにログを表示するようにします。
  // Echo.addEventListener( new Echo.Logger(System.out) ) ;

  try {
      aircon = new SoftAirconImpl() ;
      light = new SoftLightImpl() ;
      blind = new SoftBlindImpl() ;
      exTempSensor = new SoftTempSensorImpl() ;
      lock = new SoftLockImpl() ;

      Echo.start( new MyNodeProfile(),new DeviceObject[]{aircon,light,blind,exTempSensor,lock});
      
      pw = aircon.mStatus[0]-0x30 ;
      mode = aircon.mMode[0]-0x41 ;
      temp = aircon.mTemperature[0] ;
      light_pw = light.mStatus[0]-0x30 ;
      blind_open = blind.mOpen[0]-0x41 ;
      lock_locked = 0x42-lock.mLock[0] ;
      ps = aircon.mPowerSaving[0] - 0x41 ;
      af = aircon.mAirFlow[0] - 0x31 ;

      room_temp_x10 = ((exTempSensor.mTemp[0]&0xff)<<8) | (exTempSensor.mTemp[1]&0xff) ;
      if( room_temp_x10 > 0x8000 ) room_temp_x10 = room_temp_x10 - 0x10000 ;
      cp5.getController("RoomTempSlider").setValue(room_temp_x10) ;

      //httpserv = new HTTPServer(this,31413,aircon,light,blind,exTempSensor,lock) ;

  } catch( IOException e){ e.printStackTrace(); }


}

void setupImages( JSONObject node ){
  JSONArray ja ;
  switch(imgTypeMap.get( node.getString("type") ) ){
    case STACKLAYERS :
      ja = node.getJSONArray("contents") ;
      for( int ji=0;ji<ja.size();++ji )
        setupImages(ja.getJSONObject(ji)) ;
      break ;
    case SWITCHLAYERS :
      imgSwitchLayers.put(node.getString("key"),node) ;
    case ACCUMLAYERS :
      ja = node.getJSONArray("contents") ;
      for( int ji=0;ji<ja.size();++ji )
        setupImages(ja.getJSONObject(ji)) ;
      try {
        if( node.getInt("cid")<-1 || node.getInt("cid") >= ja.size() )
          node.setInt("cid",0) ;
      } catch (Exception e){node.setInt("cid",0) ;} ; 
      break ;
    case ANIMLAYERS :
      //println("Skip animlayers.") ;
      break ;
    case GAMELAYERS :
      //println("Skip gamelayer.") ;
      break ;
    case IMAGELAYER :
      if( node.getString("name").equals("icon") ) break ;
      //println("Image \""+node.getString("name")+"\" path = "+backImgPath+node.getString("url")) ;
      int imgID = imgIdToPImageMap.size();
      node.setInt("img_id",imgID) ;
      imgIdToPImageMap.put(imgID,loadImage(backImgPath+node.getString("url"))) ; 
      break ;
    case AREALAYER :
      //println("Skip arealayer.") ;
      break ;
  }
}

void switchLayer( String keyname , int cid ){
  JSONObject node = imgSwitchLayers.get(keyname) ;
  if( node == null ) return ;
  node.setInt( "cid",cid ) ;
}

void switchLayer( String keyname , String valuename ){
  JSONObject node = imgSwitchLayers.get(keyname) ;
  if( node == null ) return ;
  if( valuename == null || valuename.equals("off") ){
    node.setInt( "cid",-1 ) ;
    return ;
  }
  JSONArray ja = node.getJSONArray("contents") ;
  for( int ji=0;ji<ja.size();++ji ){
    if( ja.getJSONObject(ji).getString("value").equals(valuename) ){
      node.setInt( "cid",ji ) ;
      break ;
    }
  }
}

void draw() {
  drawImages(backImgJSON) ;
  // Draw temperature
  fill(0, 102, 153) ;
  textSize(15) ;
  text(temp+"℃", 582+35*2,8+15);

  // Draw powersaving mode
  if (ps == 0) {
    text("PowerSaving", 575,90);
  } else {
    text("Normal", 575,90);
  }

  // Draw air flow level
  switch (af) {
    case 0:  text("AirFlow: Level1", 685,90);  break;
    case 1:  text("AirFlow: Level2", 685,90);  break;
    case 2:  text("AirFlow: Level3", 685,90);  break;
    case 3:  text("AirFlow: Level4", 685,90);  break;
    case 4:  text("AirFlow: Level5", 685,90);  break;
    case 5:  text("AirFlow: Level6", 685,90);  break;
    case 6:  text("AirFlow: Level7", 685,90);  break;
    case 7:  text("AirFlow: Level8", 685,90);  break;
    case 16:
    default:
             text("AirFlow: Automatic", 685,90);  break;
  }

  exTempSensor.setTemp(room_temp_x10 = (int)(cp5.getController("RoomTempSlider").getValue())) ;
  text(String.format("%.1f℃",room_temp_x10*0.1), 160,48);

  // selected option display near buttoons
  stroke(204, 102, 0);
  strokeWeight(3);
  line( 582+  pw*35,25 , 582+pw*35+28,25 ) ;
  line( 582+mode*35,50 , 582+mode*35+28,50 ) ;
  // light
  line( 72,200+light_pw*20 ,72,200+light_pw*20+13 ) ;
  // blind
  line( 237,50+blind_open*20 ,237,50+blind_open*20+13 ) ;

  line( 777,400+(1-lock_locked)*20 ,777,400+(1-lock_locked)*20+13 ) ;


  if( httpserv != null )
    httpserv.update() ;
}

void drawImages( JSONObject node ){
  JSONArray ja ;
  switch(imgTypeMap.get( node.getString("type") ) ){
    case STACKLAYERS :
      ja = node.getJSONArray("contents") ;
      for( int ji=ja.size()-1;ji>=0;--ji )
        drawImages(ja.getJSONObject(ji)) ;
      break ;
    case ACCUMLAYERS :
    case SWITCHLAYERS :
      ja = node.getJSONArray("contents") ;
      int cid = node.getInt("cid") ;
      if( cid >= 0 )
        drawImages(ja.getJSONObject(cid)) ;
      break ;

    case IMAGELAYER :
      if( node.getString("name").equals("icon") ) break ;
      image( imgIdToPImageMap.get(node.getInt("img_id")) , node.getInt("x") , node.getInt("y")) ;
      break ;

    case ANIMLAYERS :
    case GAMELAYERS :
    case AREALAYER :
      break ;
  }
}

// Aircon switches
public void On(){ aircon.setOperationStatusBoolean(true) ; }
public void Off(){ aircon.setOperationStatusBoolean(false) ; }
public void Auto(){ aircon.setOperationModeSettingInt(0) ; }
public void Cool(){ aircon.setOperationModeSettingInt(1) ; }
public void Heat(){ aircon.setOperationModeSettingInt(2) ; }
public void Dry(){ aircon.setOperationModeSettingInt(3) ; }
public void Wind(){ aircon.setOperationModeSettingInt(4) ; }
public void Up(){ aircon.setTemperatureValueInt(temp+1) ; }
public void Down(){ aircon.setTemperatureValueInt(temp-1) ; }

// Light switches
public void LightOn(){ light.setOperationStatusBoolean(true) ; }
public void LightOff(){ light.setOperationStatusBoolean(false) ; }

// Blind switches
public void CurtainOpen(){ blind.setOpenCloseSettingBoolean(true) ; }
public void CurtainClose(){ blind.setOpenCloseSettingBoolean(false) ; }

// Lock
public void LockKey(){ lock.setLockSetting1Boolean(true) ; }
public void UnlockKey(){ lock.setLockSetting1Boolean(false) ; }
