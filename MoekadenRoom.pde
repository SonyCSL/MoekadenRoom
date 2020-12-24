import java.io.IOException;
import processing.net.*;
import controlP5.*;

import java.util.Iterator;
import java.util.Calendar ;

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
import com.sonycsl.echo.eoj.device.housingfacilities.SmartElectricEnergyMeter ;
import com.sonycsl.echo.eoj.device.housingfacilities.Buzzer ;

import com.sonycsl.echo.eoj.device.sensor.TemperatureSensor ;

// 何日前の0:00からスマートメーターのログ取得を開始したかを示す。0なら今日。
final int SMART_METER_LOG_START_DAY = 2 ;
// スマートメーターの履歴データを更新する間隔
final int SMART_METER_DATA_UPDATE_INTERVAL = 300 ;
final int AIRCON_WATTS = 300 , LIGHT_WATTS = 100 ;


public class MyNodeProfile extends NodeProfile {
  byte[] mManufactureCode = {0,0,0};  // 0x8A
  byte[] mStatus = {0x30};            // 0x80
  byte[] mVersion = {1,1,1,0};        // 0x82
  byte[] mIdNumber = {(byte)0xFE,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};  // 0x83
  byte[] mUniqueId = {0,0};           // 0xBF 
  @Override
  protected byte[] getManufacturerCode() {return mManufactureCode;}
  @Override
  protected byte[] getOperatingStatus() {  return mStatus;  }
  @Override
  protected byte[] getVersionInformation() {return mVersion;}
  @Override
  protected byte[] getIdentificationNumber() {return mIdNumber;}
  @Override
  protected boolean setUniqueIdentifierData(byte[] edt) {
    if((edt[0] & 0x40) != 0x40)   return false;
    mUniqueId[0] = (byte)((edt[0] & (byte)0x7F) | (mUniqueId[0] & 0x80));
    mUniqueId[1] = edt[1];
    return true;
  }
  @Override
  protected byte[] getUniqueIdentifierData() {return mUniqueId;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}
  @Override
  protected void setupPropertyMaps(){
    super.setupPropertyMaps() ;
    addGetProperty( EPC_MANUFACTURER_CODE ); // 0x8B
  }  
}

//////////////////////////////
//////////////////////////////
//////////////////////////////
// Airconditoner class
//////////////////////////////
//////////////////////////////
//////////////////////////////
int pw, mode, temp ;
public class SoftAirconImpl extends HomeAirConditioner {
  public byte[] mStatus = {0x31}; // 0x80:の電源状態はOFFだと仮定します。
  public byte[] mMode = {0x41};  // 初期モードは自動モードと仮定します。
  public byte[] mTemperature = {20}; // 初期の設定温度は18度と仮定します。

  //////////////////////////////////
  // 以下、必須プロパティの適当な実装です。
  // 本当はもっときちんと実装しなければいけなさそうです。
  //////////////////////////////////
  byte[] mLocation = {0x00};
  byte[] mStandardVersion = {0x01, 0x01, 0x61, 0x00}; // 0x82
  byte[] mFaultStatus = {0x42};
  byte[] mManufacturerCode = {0,0,0};  // 0x8A Usually unused. (NodeProfies's Manufacturer code IdentificationNumber are used as a whole

  protected boolean setInstallationLocation(byte[] edt) {return true;}
  protected byte[] getInstallationLocation() {return mLocation;}
  protected byte[] getStandardVersionInformation() {return mStandardVersion;}
  protected byte[] getFaultStatus() {  return mFaultStatus;}
  protected byte[] getManufacturerCode() {return mManufacturerCode;}
  
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}


  ///////////////////////////////////////////
  /// Optional settings.
  /// See https://github.com/SonyCSL/OpenECHO/blob/master/src/com/sonycsl/echo/eoj/device/DeviceObject.java
  byte[] mBusinessFacilityCode = {0x01,0x02,0x03};  // Defined by Manifacturer (3 bytes)
  byte[] mProductCode = {'M','o','e','A','i','r','c','o','n',0x00,0x00,0x00};  // ASCII name (12 bytes)
  byte[] mProductionNumber = {'4','1','3','1','4',0x00,0x00,0x00,0x00,0x00,0x00,0x00};  // Number in ASCII (12 bytes)
  byte[] mProductionDate = {(byte)((2016>>8)&0xFF),(byte)(2016&0xFF),6,8};  // Production date in binary (YYMD)
  @Override
  protected void setupPropertyMaps(){
    super.setupPropertyMaps() ;
    addGetProperty( EPC_BUSINESS_FACILITY_CODE ); // 0x8B
    addGetProperty( EPC_PRODUCT_CODE );//0x8C;
    addGetProperty( EPC_PRODUCTION_NUMBER );//0x8D;
    addGetProperty( EPC_PRODUCTION_DATE );//0x8E
  }
  @Override
  protected byte[] getBusinessFacilityCode() { return mBusinessFacilityCode ; }
  @Override
  protected byte[] getProductCode() { return mProductCode ; }
  @Override
  protected byte[] getProductionNumber() { return mProductionNumber ; }
  @Override
  protected byte[] getProductionDate() { return mProductionDate ; }

  // 以下はわりかし真面目な実装です。
  // 電源のON/OFF操作です。
  protected boolean setOperationStatus(byte[] edt) {
    if( mStatus[0] != edt[0] ){
	smartMeter.baseEnergy += (edt[0]==0x30 ? AIRCON_WATTS : -AIRCON_WATTS ) ;
    }
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
    if( mStatus[0] != edt[0] ){
	smartMeter.baseEnergy += (edt[0]==0x30 ? LIGHT_WATTS : -LIGHT_WATTS ) ;
    }

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

//////////////////////////////
//////////////////////////////
//////////////////////////////
// Buzzer class
//////////////////////////////
//////////////////////////////
//////////////////////////////
public class SoftBuzzerImpl extends Buzzer {
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

  byte[] mBuzzerSoundType = {0x31} ;
  protected boolean setBuzzerSoundType(byte[] edt){
    mBuzzerSoundType[0] = edt[0] ;
    return true ;
  }
  protected byte[] getBuzzerSoundType() { return mBuzzerSoundType; }

  @Override
  protected void setupPropertyMaps(){
    super.setupPropertyMaps() ;
    addGetProperty( EPC_BUZZER_SOUND_TYPE ); // 0xE0
    addSetProperty( EPC_BUZZER_SOUND_TYPE ); // 0xE0
  }  

}

SoftBuzzerImpl buzzer ;


//////////////////////////////
//////////////////////////////
//////////////////////////////
// Smart meter class (0x0288
// https://github.com/SonyCSL/OpenECHO/blob/master/src/com/sonycsl/echo/eoj/device/housingfacilities/SmartElectricEnergyMeter.java
//////////////////////////////
//////////////////////////////
//////////////////////////////
public class SoftElectricEnergyMeter extends SmartElectricEnergyMeter  {
  public byte[] mStatus = {0x30};// Always on
  public byte[] mLock = {0x41};  // Locked(0x42:Unlocked)

  byte[] mLocation = {0x00};
  byte[] mVersion = {0x01, 0x01, 0x61, 0x00};
  byte[] mFaultStatus = {0x42};
  byte[] mManufacturerCode = {0,0,0};
  
  SoftElectricEnergyMeter(){
    super() ;

  }

  @Override
  protected void setupPropertyMaps(){
    super.setupPropertyMaps() ;
    addGetProperty(EPC_NUMBER_OF_EFFECTIVE_DIGITS_FOR_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY ) ;  // D7
    addGetProperty(EPC_MEASURED_CUMULATIVE_AMOUNT_OF_ELECTRIC_ENERGY_NORMAL_DIRECTION ) ;        // E0
    addGetProperty(EPC_UNIT_FOR_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_NORMAL_AND_REVERSE_DIRECTIONS ) ;  // E1
    addGetProperty(EPC_HISTORICAL_DATA_OF_MEASURED_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_NORMAL_DIRECTION ) ;  // E2
    addSetProperty(EPC_DAY_FOR_WHICH_THE_HISTORICAL_DATA_OF_MEASURED_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_IS_TO_BE_RETRIEVED) ;  // E5
    addGetProperty(EPC_DAY_FOR_WHICH_THE_HISTORICAL_DATA_OF_MEASURED_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_IS_TO_BE_RETRIEVED) ;  // E5
    addGetProperty(EPC_MEASURED_INSTANTANEOUS_ELECTRIC_ENERGY ) ; // E7
    addGetProperty(EPC_MEASURED_INSTANTANEOUS_CURRENTS ) ; // E8
    addGetProperty(EPC_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_MEASURED_AT_FIXED_TIME_NORMAL_DIRECTION ) ; // EA
/*    addGetProperty( EPC_BUSINESS_FACILITY_CODE ); // 0x8B
    addGetProperty( EPC_PRODUCT_CODE );//0x8C;
    addGetProperty( EPC_PRODUCTION_NUMBER );//0x8D;
    addGetProperty( EPC_PRODUCTION_DATE );//0x8E
*/
  }


  protected boolean setInstallationLocation(byte[] edt) {return true;}
  protected byte[] getInstallationLocation() {return mLocation;}
  protected byte[] getStandardVersionInformation() {return mVersion;}
  protected byte[] getFaultStatus() {  return mFaultStatus;}
  protected byte[] getManufacturerCode() {return mManufacturerCode;}
//  protected byte[] getStatusChangeAnnouncementPropertyMap() {  return null;}
//  protected byte[] getSetPropertyMap() {return null;}
//  protected byte[] getGetPropertyMap() {return null;}

  protected byte[] getOperationStatus() { return mStatus; }
  
  
  // D7 積算電力量有効桁数 (1～8)
  byte[] numberOfEffectiveDigitsForCumulativeAmountsOfElectricEnergy = new byte[]{0x08} ;
    @Override
    protected byte[] getNumberOfEffectiveDigitsForCumulativeAmountsOfElectricEnergy() {
        return numberOfEffectiveDigitsForCumulativeAmountsOfElectricEnergy ;
    }

  // E0 積算電力量 in kWh
  // 現在はEAと同じく、getCumlativeEnergy()を用いて
  // 30分間隔サンプルの最新値を返すようになっている。
  byte[] measuredCumulativeAmountOfElectricEnergyNormalDirection = new byte[]{1,0,0,0} ;
    @Override
    protected byte[] getMeasuredCumulativeAmountOfElectricEnergyNormalDirection() {
	float energy = getCumlativeEnergy( 0 , getLatestIndexHalfHour() ) ;
	setIntValueTo4Bytes( (energy>=0 ? (int)(energy / getCumUnit()) : 0xFFFFFFFE)
		, measuredCumulativeAmountOfElectricEnergyNormalDirection
		, 0 ) ; // Previously 4
        return measuredCumulativeAmountOfElectricEnergyNormalDirection ;
    }

  // E1 積算電力量の単位 0～0D. 0x02は0.01kWh
  byte[] unitForCumulativeAmountsOfElectricEnergyNormalAndReverseDirections = new byte[]{0x02} ;
    @Override
    protected byte[] getUnitForCumulativeAmountsOfElectricEnergyNormalAndReverseDirections() {
        return unitForCumulativeAmountsOfElectricEnergyNormalAndReverseDirections;
    }

  // E2 積算電力量 計測値履歴１ (正方向計測値)
  // 積算履歴収集日１と該当収集日の 24 時間 48 コマ分（0 時 0 分～23 時 30 分）の正方向の定時
  // 積算電力量計測値の履歴データを時系列順に上位バイトからプロパティ値として示す。
  // 1～2 バイト目：積算履歴収集日 0x0000～0x0063(0～99) 3 バイト目以降：積算電力量計測値
  // 0x00000000～0x05F5E0FF (0～99,999,999)
  // 下の方の、getCumlativeEnergy()を用いて計算。
  byte[] historicalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection = new byte[194]  ;
  @Override
    protected byte[] getHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection() {
    int day = mDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved[0] ;
    // very naive implementation that requires O(n^2)
    historicalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection[0] = 0 ;
    historicalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection[1] = (byte)day ;

    final float cumUnit = getCumUnit() ;
    for( int di=0;di<48;++di ){
	float cumE = getCumlativeEnergy(day,di) ;
	setIntValueTo4Bytes(
		( cumE >= 0 ? (int)(cumE/cumUnit) : 0xFFFFFFFE )
		,historicalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection
		,di*4+2 ) ;
    }
    return historicalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection ;
  }

  // E3は逆方向の積算電力量計測値、E4は逆方向の積算電力量計測値履歴。
  // 必須プロパティだがMoekadenRoomでは意味のある値を返すように実装していない。
  // (プロパティ自体は存在するが、返答としてはエラーが返るはず

  // E5 積算履歴収集日 30分毎の計測値履歴データを収集する日を示す。 
  // 0x00～0x63 ( 0～99)  0:当日 1～99:前日の日数
  byte[] mDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved = {(byte)0} ;
  @Override
  boolean setDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved(byte[] edt) {
    //println("Day for retrieval => "+edt[0] ) ;
	mDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved[0] = edt[0] ;
	return true;
  }
  @Override
  protected byte[] getDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved() {
	return mDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved ;
  }

  // E7 瞬時電力計測値 in W.
  // 0x80000001～0x7FFFFFFD (-2,147,483,647～ 2,147,483,645)
  // 下の方の、getInstantaneousEnergy()を用いて計算。
  byte[] measuredInstantaneousElectricEnergy = new byte[4] ;
  @Override
  protected byte[] getMeasuredInstantaneousElectricEnergy() {
	byte[] re = new byte[4] ;
	setIntValueTo4Bytes( (int)getInstantaneousEnergy() , re , 0 ) ;
	return re ;
  }

  // E8 瞬時電力計測値 in 0.1A.
  // 実効電流値の瞬時値を 0.1A 単位で R 相 T 相を並べて示す。単相 2 線式の場合は、T 相に0x7FFE をセット。
  // 0x8001～0x7FFD（R 相）：0x8001～0x7FFD（T 相）(-3,276.7～3,276.5):(-3,276.7～3,276.5)
  // 下のほうの、getInstantaneousCurrentR() と getInstantaneousCurrentT() を用いて計算。
  byte[] measuredInstantaneousCurrents = new byte[4] ;
  @Override
  protected byte[] getMeasuredInstantaneousCurrents() {
	float r = getInstantaneousCurrentR() , t = getInstantaneousCurrentT() ;
	byte[] buf = new byte[8] ;
	setIntValueTo4Bytes( (int)(r*10) , buf , 0 ) ;
	setIntValueTo4Bytes( (int)(t*10) , buf , 4 ) ;

	return new byte[]{buf[2],buf[3],buf[6],buf[7]} ;
  }


  // EA 最新の 30 分毎の計測時刻における積算電力量(正方向計測値)を、計測年月日を 4 バイト、
  // 計測時刻を 3 バイト、積算電力量（正方向計測値）4 バイトで示す。
  // ・計測年月日 YYYY:MM:DD ・計測時刻 hh:mm:ss ・積算電力量 10進表記で最大8桁
  // 下の方の getCumlativeEnergy() から計算される。計測年月日・時刻は現在時刻にセットされる。
    @Override
    protected byte[] getCumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection() {
      byte[] ret = new byte[11] ;

      Calendar c = Calendar.getInstance();
      ret[0] = (byte)(c.get(Calendar.YEAR)/256) ;
      ret[1] = (byte)(c.get(Calendar.YEAR)%256) ;
      ret[2] = (byte)(c.get(Calendar.MONTH) + 1) ;
      ret[3] = (byte)(c.get(Calendar.DATE)) ;
      ret[4] = (byte)(c.get(Calendar.HOUR_OF_DAY)) ;
      ret[5] = (byte)(c.get(Calendar.MINUTE)<30 ? 0 : 30) ;
      ret[6] = 0 ;

      int indexHalfHour = getLatestIndexHalfHour() ;

      float energy = getCumlativeEnergy( indexHalfHour==47?1:0 , indexHalfHour ) ;
      int energy_long = (energy >= 0 ? (int)(energy / getCumUnit()) : 0xFFFFFFFE);
      setIntValueTo4Bytes( energy_long , ret , 7 ) ;

      return ret;
    }

  // EBはDAの逆方向版だが、MoekadenRoomでは実装していない。



  ////////////////////////////////////////////////////////////////////////////////////////////
  ////////////////////////////////////////////////////////////////////////////////////////////
  // 電力関連値の設定・コールバック。
  // これを変更することで、任意の電力値を返すように変更できる。
  // デフォルトではランダムな値を返すようにしている。
  // ※ただし、エアコンや照明の具合でちょっとだけ増減させている。
  int baseEnergy = 0 ;
  int getInstantaneousEnergy(){ // 現在の電力瞬時値をW単位で返す。
	// Use noise() (rather than random()) for the value continuity
	return baseEnergy + (int)( noise(0.3*(int)(millis()/1000))*2000 );
  }

  // 現在の電力瞬時値（R相とT相）をA単位で返す。デフォルトは上記
  // getInstantaneousEnergy()を100で割ったもの。
  float getInstantaneousCurrentR(){ return getInstantaneousEnergy()/100.0f;  }
  float getInstantaneousCurrentT(){ return getInstantaneousEnergy()/100.0f;  }

  // 30分スロットごとの積算電力値ログ in kWh。単調増加でなくてはならない。
  // 引数１は「日」、今日を0とし、数が多くなるほど前の日の30分スロットのデータ。最大99.
  // 引数２は「３０分スロット番号」これは、0なら0:00, 1なら0:30のように、１日を30分ごとに
  //   区切った時のどの履歴を示すかのインデックス。0以上47以下の値。
  // エラーの場合は-1を返すこと。
  // 例えば、昨日の16:00のデータの場合、1,32となる。
  float[] cumLog ;
  int prevAccessLatestHalfHour = -1 ;
  final float MAX_CUMENERGY_PER_HOUR = 2.0f ;
  float getCumlativeEnergy(int day,int indexHalfHour){
	int latestHalfHour = getLatestIndexHalfHour() ;

	if( cumLog == null ){	// データ初期化。
		int loglen = (SMART_METER_LOG_START_DAY+1) * 48 ;
		cumLog = new float[loglen] ;
		cumLog[0] = 0 ;
		for( int li=1;li<loglen;++li )
			cumLog[li] = cumLog[li-1] + random(MAX_CUMENERGY_PER_HOUR/2) ;	// 30分間隔なので2で割る。
	}

	if( latestHalfHour == 0 && prevAccessLatestHalfHour == 47){
		// New day should be added to the history data (cumLog)
		float[] newLog = new float[cumLog.length+48] ;
		// Copy existing data
		for( int i = 0 ; i < cumLog.length ; ++i )	newLog[i] = cumLog[i] ;
		// add now data at the tail
		for( int i = 0 ; i < 48 ; ++i )
			newLog[cumLog.length+i] = newLog[cumLog.length+i-1] + random(MAX_CUMENERGY_PER_HOUR/2) ;
		cumLog = newLog ;
	}
	prevAccessLatestHalfHour = latestHalfHour ;

	if( day == 0 && indexHalfHour > latestHalfHour )
		return -1 ;	// 未来のデータ

	int stored_days = cumLog.length/48 ; // including today
	if( day >= stored_days )
		return -1 ;	// ログ取得開始前

	return cumLog[(stored_days-day-1)*48+indexHalfHour] ;
  }
  // 現在時刻を参照して、最新のデータが入っているlatestIndexHalfHourを返す。
  int getLatestIndexHalfHour(){
	Calendar c = Calendar.getInstance();
	return c.get(Calendar.HOUR_OF_DAY)*2 + (c.get(Calendar.MINUTE)<30 ? 0 : 1) ;
  }

  // 履歴の単位を返すユーティリティ関数。
  float getCumUnit(){
	int b = unitForCumulativeAmountsOfElectricEnergyNormalAndReverseDirections[0] ;
	return pow( 10, (b<5?-b:b-10) ) ;
  }

}

SoftElectricEnergyMeter smartMeter ;

// Utility functions
void setIntValueTo4Bytes( int inval,byte[] outArray,int outStartIndex ){
	outArray[outStartIndex+3] = (byte)(inval%256) ;
	outArray[outStartIndex+2] = (byte)((inval>>8)%256) ;
	outArray[outStartIndex+1] = (byte)((inval>>16)%256) ;
	outArray[outStartIndex+0] = (byte)((inval>>24)%256) ;
}
int getIntValueFrom4Bytes( byte[] srcArray,int srcStartIndex ){
	return (int)(srcArray[srcStartIndex]&0xFF)<<24
	    |  (int)(srcArray[srcStartIndex+1]&0xFF)<<16
	    |  (int)(srcArray[srcStartIndex+2]&0xFF)<<8
	    |  (int)(srcArray[srcStartIndex+3]&0xFF) ;
}











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

void settings() {
  backImgJSON = loadJSONObject(backImgPath+"setup.json") ;
  size(backImgJSON.getInt("width"),backImgJSON.getInt("height"));
}

void setup() {
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
      smartMeter = new SoftElectricEnergyMeter() ;
      //buzzer = new SoftBuzzerImpl() ;

      Echo.start( new MyNodeProfile(),new DeviceObject[]{
        aircon
        ,light
        ,blind
        ,exTempSensor
        ,lock
        ,smartMeter
        //, buzzer
      });
      
      pw = aircon.mStatus[0]-0x30 ;
      mode = aircon.mMode[0]-0x41 ;
      temp = aircon.mTemperature[0] ;
      light_pw = light.mStatus[0]-0x30 ;
      blind_open = blind.mOpen[0]-0x41 ;
      lock_locked = 0x42-lock.mLock[0] ;

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

int smartMeterDataUpdateCountdown = 0 ;
float[] smartMeterDataCache ;

void draw() {
  drawImages(backImgJSON) ;
  // Draw temperature
  fill(0, 102, 153) ;
  textSize(15) ;
  text(temp+"℃", 582+35*2,8+15);

  exTempSensor.setTemp(room_temp_x10 = (int)(cp5.getController("RoomTempSlider").getValue())) ;
  text(String.format("%.1f℃",room_temp_x10*0.1), 160,48);

  // selected option display near buttoons
  stroke(204, 102, 0);
  strokeWeight(3);
  line( 582+  pw*35,25 , 582+pw*35+28,25 ) ;
  line( 582+mode*35,50 , 582+mode*35+28,50 ) ;
  // Light
  line( 72,200+light_pw*20 ,72,200+light_pw*20+13 ) ;
  // Blind
  line( 237,50+blind_open*20 ,237,50+blind_open*20+13 ) ;
  // Door lock
  line( 777,400+(1-lock_locked)*20 ,777,400+(1-lock_locked)*20+13 ) ;

  // Smart meter related
  if( smartMeterDataCache == null || --smartMeterDataUpdateCountdown < 0 ){
	smartMeterDataUpdateCountdown = SMART_METER_DATA_UPDATE_INTERVAL ;
	final float cumUnit = smartMeter.getCumUnit() ;

	byte days = (byte)(smartMeter.cumLog==null?SMART_METER_LOG_START_DAY+1:smartMeter.cumLog.length/48) ;
	smartMeterDataCache = new float[days*48] ;
	byte[] buf ;
	int smi = 0 ;
	for( int day=days-1;day>=0;--day ){
		smartMeter.setDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved( new byte[]{(byte)day}) ;
		buf = smartMeter.getHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection() ;

		for( int si=0;si<48;++si ){
			int lv = getIntValueFrom4Bytes( buf,2+si*4 ) ;
			smartMeterDataCache[ smi++ ] = (lv<0?-1:lv*cumUnit) ;
		}
	}
  }

  {
    // Draw smart meter data
    final int sm_x=10,sm_y=400,sm_w=300,sm_h=70 ;
    fill( 0, 102, 153, 128 ) ;
    strokeWeight(0) ;
    rect( sm_x,sm_y,sm_w,sm_h ) ;
    fill( 255,255,255 ) ;
    textSize(13) ;

    // History
    final int sday_max = (int)(smartMeterDataCache.length/48) ;

    // The index of cached data
    float prev_val = 0 , sm_mul = 0.7f / (smartMeter.MAX_CUMENERGY_PER_HOUR/2) ;
    int prev_x = sm_x ;
    strokeWeight(2) ;
    for( int smi = 1 ; smi < smartMeterDataCache.length ; ++smi ){
	int cur_x = sm_x + sm_w * smi / smartMeterDataCache.length ;

	if( (smi%48) == 0 ){
		stroke(180) ;
		line(cur_x,sm_y,cur_x,sm_y+sm_h) ;
	}


	float cur_val ;
	if( smartMeterDataCache[smi] < 0 || smartMeterDataCache[smi-1] < 0 )
		cur_val = -1 ;
	else	cur_val = smartMeterDataCache[smi] - smartMeterDataCache[smi-1] ;

	int py = sm_y + (int)(sm_h * (1.0f-prev_val * sm_mul)) ;
	int cy = sm_y + (int)(sm_h * (1.0f-cur_val  * sm_mul)) ;

	if( prev_val >= 0 && cur_val >= 0 ){
		stroke(255) ;
		line(prev_x,py,cur_x,cy) ;
	} else if( prev_val < 0 && cur_val < 0 ){
		stroke(255,0,0) ;
		line(prev_x,sm_y+sm_h-1,cur_x,sm_y+sm_h-1) ;
		cur_val = -1 ;
	}
	prev_x = cur_x ;
	prev_val = cur_val ;
    }

    // Instantaneous
    text( "Smart meter / Using "+ smartMeter.getInstantaneousEnergy() +" W", 15 , 415 ) ;
  }
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
public void On(){
  aircon.setOperationStatusBoolean(true) ;
}
public void Off(){
   aircon.setOperationStatusBoolean(false) ;

 }
public void Auto(){ aircon.setOperationModeSettingInt(0) ; }
public void Cool(){ aircon.setOperationModeSettingInt(1) ; }
public void Heat(){ aircon.setOperationModeSettingInt(2) ; }
public void Dry(){ aircon.setOperationModeSettingInt(3) ; }
public void Wind(){ aircon.setOperationModeSettingInt(4) ; }
public void Up(){ aircon.setTemperatureValueInt(temp+1) ; }
public void Down(){ aircon.setTemperatureValueInt(temp-1) ; }

// Light switches
public void LightOn(){
  light.setOperationStatusBoolean(true) ;
}
public void LightOff(){
  light.setOperationStatusBoolean(false) ;
}

// Blind switches
public void CurtainOpen(){ blind.setOpenCloseSettingBoolean(true) ; }
public void CurtainClose(){ blind.setOpenCloseSettingBoolean(false) ; }

// Lock
public void LockKey(){ lock.setLockSetting1Boolean(true) ; }
public void UnlockKey(){ lock.setLockSetting1Boolean(false) ; }
