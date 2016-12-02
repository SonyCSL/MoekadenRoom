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

import com.sonycsl.echo.eoj.device.sensor.TemperatureSensor ;



public class MyNodeProfile extends NodeProfile {
  byte[] mManufactureCode = {1,2,3};  // 0x8A
  byte[] mStatus = {0x30};            // 0x80
  byte[] mVersion = {1,1,1,0};        // 0x82
  //byte[] mIdNumber = {(byte)0xFE,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};  // 0x83
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
  byte[] mManufacturerCode = {3,2,1};  // 0x8A Usually unused. (NodeProfies's Manufacturer code IdentificationNumber are used as a whole

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
  byte[] mProductionDate = {(byte)(2016>>8),(byte)(2016&0xFF),6,8};  // Production date in binary (YYMD)
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
    mStatus[0] = edt[0];
    pw = edt[0]-0x30 ;
    try {
      inform().reqInformOperationStatus().send();
        smartMeter.setInstantaneousElectricEnergy_Diff(edt[0] == 0x30?300:-300) ;
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
    mStatus[0] = edt[0];
    light_pw = edt[0]-0x30 ;
    try {
      inform().reqInformOperationStatus().send();
        smartMeter.setInstantaneousElectricEnergy_Diff(edt[0] == 0x30?40:-40) ;
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
    addGetProperty(EPC_NUMBER_OF_EFFECTIVE_DIGITS_FOR_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY ) ;  // D7
    addGetProperty(EPC_MEASURED_CUMULATIVE_AMOUNT_OF_ELECTRIC_ENERGY_NORMAL_DIRECTION ) ;        // E0
    addGetProperty(EPC_UNIT_FOR_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_NORMAL_AND_REVERSE_DIRECTIONS ) ;  // E1
    addGetProperty(EPC_HISTORICAL_DATA_OF_MEASURED_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_NORMAL_DIRECTION ) ;  // E2
    addSetProperty(EPC_DAY_FOR_WHICH_THE_HISTORICAL_DATA_OF_MEASURED_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_IS_TO_BE_RETRIEVED) ;  // E5
    addGetProperty(EPC_DAY_FOR_WHICH_THE_HISTORICAL_DATA_OF_MEASURED_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_IS_TO_BE_RETRIEVED) ;  // E5
    addGetProperty(EPC_MEASURED_INSTANTANEOUS_ELECTRIC_ENERGY ) ; // E7
    addGetProperty(EPC_MEASURED_INSTANTANEOUS_CURRENTS ) ; // E8
    addGetProperty(EPC_CUMULATIVE_AMOUNTS_OF_ELECTRIC_ENERGY_MEASURED_AT_FIXED_TIME_NORMAL_DIRECTION ) ; // EA

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
  
  
  // D7
  byte[] numberOfEffectiveDigitsForCumulativeAmountsOfElectricEnergy = new byte[]{0x08} ;
      @Override
    protected byte[] getNumberOfEffectiveDigitsForCumulativeAmountsOfElectricEnergy() {
        return numberOfEffectiveDigitsForCumulativeAmountsOfElectricEnergy ;
    }

  // E0
  byte[] measuredCumulativeAmountOfElectricEnergyNormalDirection = new byte[]{1,0,0,0} ;
    @Override
    protected byte[] getMeasuredCumulativeAmountOfElectricEnergyNormalDirection() {
        return measuredCumulativeAmountOfElectricEnergyNormalDirection ;
    }

// E1
  byte[] unitForCumulativeAmountsOfElectricEnergyNormalAndReverseDirections = new byte[]{0x02} ;
    @Override
    protected byte[] getUnitForCumulativeAmountsOfElectricEnergyNormalAndReverseDirections() {
        return unitForCumulativeAmountsOfElectricEnergyNormalAndReverseDirections;
    }
  // E2
  byte[] historicalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection = new byte[194]  ;
  @Override
    protected byte[] getHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection() {
    return historicalDataOfMeasuredCumulativeAmountsOfElectricEnergyNormalDirection;
  }

// E5
  boolean setDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved(byte[] edt) {return true;}
  protected byte[] getDayForWhichTheHistoricalDataOfMeasuredCumulativeAmountsOfElectricEnergyIsToBeRetrieved() {return new byte[]{0};}

// E7
  byte[] measuredInstantaneousElectricEnergy = new byte[4] ;
  protected byte[] getMeasuredInstantaneousElectricEnergy() {return measuredInstantaneousElectricEnergy;}
// E8
  byte[] measuredInstantaneousCurrents = new byte[4] ;
  protected byte[] getMeasuredInstantaneousCurrents() {return measuredInstantaneousCurrents;}
// EA
  byte[] cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection ;
    @Override
    protected byte[] getCumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection() {
      if( cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection == null ){
        cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection = new byte[15] ;
      }
      Calendar c = Calendar.getInstance();
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[0] = (byte)(c.get(Calendar.YEAR)/256) ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[1] = (byte)(c.get(Calendar.YEAR)%256) ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[2] = (byte)(c.get(Calendar.MONTH) + 1) ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[3] = (byte)(c.get(Calendar.DATE)) ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[4] = (byte)(c.get(Calendar.HOUR_OF_DAY)) ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[5] = (byte)(c.get(Calendar.MINUTE)<=30 ? 0 : 30) ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[6] = 0 ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[7] = measuredCumulativeAmountOfElectricEnergyNormalDirection[0] ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[8] = measuredCumulativeAmountOfElectricEnergyNormalDirection[1] ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[9] = measuredCumulativeAmountOfElectricEnergyNormalDirection[2] ;
      cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection[10] = measuredCumulativeAmountOfElectricEnergyNormalDirection[3] ;

        return cumulativeAmountsOfElectricEnergyMeasuredAtFixedTimeNormalDirection;
    }
  
  
  public long instantaneousElectricEnergy = 123 ; //
  public void setInstantaneousElectricEnergy( long watts ){
    instantaneousElectricEnergy = watts ;
    
    measuredInstantaneousElectricEnergy[3] = (byte)(watts%256) ;
    measuredInstantaneousElectricEnergy[2] = (byte)((watts>>8)%256) ;
    measuredInstantaneousElectricEnergy[1] = (byte)((watts>>16)%256) ;
    measuredInstantaneousElectricEnergy[0] = (byte)((watts>>24)%256) ;
    
    long A = watts/100 ;

    measuredInstantaneousCurrents[3] = (byte)(A%256) ;
    measuredInstantaneousCurrents[2] = (byte)((A>>8)%256) ;
    measuredInstantaneousCurrents[1] = (byte)((A>>16)%256) ;
    measuredInstantaneousCurrents[0] = (byte)((A>>24)%256) ;
  }
  public void setInstantaneousElectricEnergy_Diff( long watts_diff ){
    setInstantaneousElectricEnergy( instantaneousElectricEnergy + watts_diff ) ; 
  }
}

SoftElectricEnergyMeter smartMeter ;









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

      Echo.start( new MyNodeProfile(),new DeviceObject[]{aircon,light,blind,exTempSensor,lock,smartMeter});
      
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
  // light
  line( 72,200+light_pw*20 ,72,200+light_pw*20+13 ) ;
  // blind
  line( 237,50+blind_open*20 ,237,50+blind_open*20+13 ) ;

  line( 777,400+(1-lock_locked)*20 ,777,400+(1-lock_locked)*20+13 ) ;

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
  smartMeter.setInstantaneousElectricEnergy_Diff(-40) ;
}

// Blind switches
public void CurtainOpen(){ blind.setOpenCloseSettingBoolean(true) ; }
public void CurtainClose(){ blind.setOpenCloseSettingBoolean(false) ; }

// Lock
public void LockKey(){ lock.setLockSetting1Boolean(true) ; }
public void UnlockKey(){ lock.setLockSetting1Boolean(false) ; }