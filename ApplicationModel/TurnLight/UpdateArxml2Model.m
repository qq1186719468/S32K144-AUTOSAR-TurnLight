disp('.....Running.......')
[ModelFile,~] = uigetfile('*.slx;*.mdl');
[ArxmlFile,~] = uigetfile('*.arxml');
if ~isequal(ModelFile,0)&&~isequal(ArxmlFile,0)
    open_system(ModelFile)
    ar = arxml.importer(ArxmlFile);
    updateModel(ar,ModelFile)
end
disp('.......Update Arxml Done......')