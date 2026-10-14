%Created in 2022/9/25
%Created by Zeng Yuqiao
disp('......Running......')
Cache=who;
for i=1:length(Cache)
    eval('clear(Cache{i})');
end
[ArxmlFile,~] = uigetfile('*.arxml');
if ~isequal(ArxmlFile,0)   
    ar = arxml.importer(ArxmlFile);
    names = getComponentNames(arxml.importer(ArxmlFile));
    for i=1:length(names)
    createComponentAsModel(ar,names{i},'ModelPeriodicRunnablesAs','FunctionCallSubsystem');
    
    save_system;
    get_param(bdroot,'Name');
    clear i Cache ar names ans ArxmlFile;
    evalin('base',"matlab.io.saveVariablesToScript(strcat(get_param(bdroot,'Name'),'_data.m'))");
    end
end
disp('......Import Arxml Done......')