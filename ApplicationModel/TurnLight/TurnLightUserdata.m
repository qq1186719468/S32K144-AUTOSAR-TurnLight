
%%%%%%%%%%
IGN_OFF = 0;
IGN_ACC = 1;
IGN_ON  = 2;
IGN_IGNST= 3;
%%%%%%%%%%
TLSW_OFF = 0;
TLSW_LEFT = 1;
TLSW_RIGHT = 2;
%%%%%%%%%%%%
TLSR_OFF = 0;
TLSR_LEFT_ON = 1;
TLSR_RIGHT_ON = 2;
%%%%%%%%%%%%
TLSWMODE_FLASH0 = 0;
TLSWMODE_FLASH3 = 1;
TLSWMODE_FLASHLONG = 2;
%%%%%%%%%%%%%%
HAZARDQR_OFF =0;
HAZARDQR_ON =1;
%%%%%%%%%%%%%%
NO_CRASH = 0;
EBL_NO_REQ = 0;
EBL_REQ = 1;
VS_VALID = 1;
%%%%%%%%%%%%%%
HAZARDSW_OFF = 0;
HAZARDSW_ON = 1;
%%%%%%%%%%%%%
HAZARDRQ_OFF = 0;
HAZARDRQ_ON = 1;
%%%%%%%%%%
TLFB_OFF = 0;
TLFB_SHORT = 1;
TLFB_OPEN = 2;
%%%%%%%%%
TLCC_OFF = 0;
TLCC_ON = 1;
%%%%%%%%%%
Simulink.defineIntEnumType( 'DiagStType', ...
   {'NORMAL','SHORT','OPEN'}, ...
   [0 1 2], ...
   'DefaultValue', 'NORMAL', ...
   'StorageType', 'uint8', ...
   'HeaderFile', 'TurnLightData.h', ...
   'AddClassNameToEnumNames', false);

Simulink.defineIntEnumType( 'TurnLightDecideStType', ...
   {'ALLOFF','ALLON','LEFTSHORT','LEFTLONG','RIGHTSHORT','RIGHTLONG'}, ...
   [0 1 2 3 4 5], ...
   'DefaultValue', 'ALLOFF', ...
   'StorageType', 'uint8', ...
   'HeaderFile', 'TurnLightData.h', ...
   'AddClassNameToEnumNames', false);


