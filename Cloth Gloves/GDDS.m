function GDDS()
% Glove Defect Detection System v3 — CT036-3-IPPR | APU
% Tri-Mask Segmentation: maskA (white glove), maskB (dark BG), maskC (BG diff)
% Three defect detectors: Holes (topology), Discoloration (CIELAB MAD), Deformation (height profile)

    appData.img=[]; appData.currentPage=1; appData.pipePg=1;
    appData.datasetFolder=''; appData.datasetFiles={};

    % Color palette
    C.bg    =[0.09 0.11 0.17]; C.panel=[0.13 0.16 0.23];
    C.accent=[0.20 0.45 0.88]; C.green=[0.15 0.78 0.42];
    C.orange=[1.00 0.58 0.18]; C.cyan =[0.18 0.82 0.88];
    C.textW =[0.95 0.95 0.98]; C.textD=[0.55 0.58 0.66];
    C.border=[0.22 0.26 0.36];
    DC.Holes  =[1.00 0.18 0.18];
    DC.Disco  =[1.00 0.62 0.08];
    DC.Deform =[0.08 0.90 0.90];

    lastFolderFile = fullfile(tempdir, 'gdds_v3_lastfolder.mat');

    scr=get(0,'ScreenSize'); winW=1060; winH=640;
    hFig=figure('Name','Glove Defect Detection System','NumberTitle','off',...
        'MenuBar','none','ToolBar','none','Color',C.bg,'Resize','off',...
        'Position',[(scr(3)-winW)/2 (scr(4)-winH)/2 winW winH]);

    % Header bar
    uipanel('Parent',hFig,'BackgroundColor',C.accent,'Units','pixels',...
        'Position',[0 winH-54 winW 54],'BorderType','none');
    uicontrol('Parent',hFig,'Style','text',...
        'String','  GLOVE DEFECT DETECTION SYSTEM',...
        'FontSize',14,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',C.accent,'HorizontalAlignment','left',...
        'Units','pixels','Position',[8 winH-50 520 38]);
    uicontrol('Parent',hFig,'Style','text','String','CT036-3-IPPR  |  APU  |  Khoo Bing Yuan',...
        'FontSize',9,'ForegroundColor',[0.82 0.92 1.00],'BackgroundColor',C.accent,...
        'HorizontalAlignment','right','Units','pixels',...
        'Position',[winW-230 winH-46 218 28]);

    % Left panel
    pnlW=268;
    uipanel('Parent',hFig,'BackgroundColor',C.panel,'Units','pixels',...
        'Position',[0 0 pnlW winH-54],'BorderType','line','HighlightColor',C.border);

    y=winH-54-16;

    % Dataset folder section
    sLbl('DATASET FOLDER',y);              y=y-32;
    uicontrol('Parent',hFig,'Style','pushbutton',...
        'String','  Browse Folder','FontSize',9,'FontWeight','bold',...
        'ForegroundColor',C.textW,'BackgroundColor',C.accent,...
        'Units','pixels','Position',[10 y pnlW-18 28],...
        'Callback',@onBrowseFolder);                 y=y-18;
    hLblFolder=uicontrol('Parent',hFig,'Style','text',...
        'String','No folder set','FontSize',7,...
        'ForegroundColor',C.textD,'BackgroundColor',C.panel,...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 14]);               y=y-86;

    % Image listbox — single click auto-loads
    hListBox=uicontrol('Parent',hFig,'Style','listbox',...
        'String',{'(no folder loaded)'},'FontSize',8,...
        'ForegroundColor',C.textW,'BackgroundColor',[0.07 0.09 0.14],...
        'SelectionHighlight','on','Units','pixels',...
        'Position',[10 y pnlW-18 82],'Callback',@onListSelect);  y=y-26;

    % Refresh and single file buttons
    uicontrol('Parent',hFig,'Style','pushbutton','String','↺ Refresh',...
        'FontSize',8,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.18 0.22 0.38],'Units','pixels',...
        'Position',[10 y round((pnlW-22)/2) 22],'Callback',@onRefreshFolder);
    uicontrol('Parent',hFig,'Style','pushbutton','String','+ Single File',...
        'FontSize',8,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.18 0.22 0.38],'Units','pixels',...
        'Position',[10+round((pnlW-22)/2)+4 y round((pnlW-22)/2) 22],...
        'Callback',@onUpload);                       y=y-18;
    hLblFile=uicontrol('Parent',hFig,'Style','text','String','No image loaded',...
        'FontSize',7,'ForegroundColor',C.textD,'BackgroundColor',C.panel,...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 14]);               y=y-82;
    hAxPrev=axes('Parent',hFig,'Units','pixels','Position',[10 y pnlW-18 78],...
        'Color',C.bg,'XColor',C.border,'YColor',C.border,...
        'XTick',[],'YTick',[],'Box','on');
    title(hAxPrev,'Preview','Color',C.textD,'FontSize',7); y=y-20;

    % Detection section
    sLbl('DETECTION',y);                   y=y-32;
    hBtnDetect=uicontrol('Parent',hFig,'Style','pushbutton',...
        'String','  Run Detection','FontSize',10,'FontWeight','bold',...
        'ForegroundColor',C.textW,'BackgroundColor',[0.16 0.52 0.30],...
        'Units','pixels','Position',[10 y pnlW-18 28],'Callback',@onDetect);
    set(hBtnDetect,'Enable','off');        y=y-18;

    % Status
    sLbl('STATUS',y);                      y=y-46;
    hStatus=uicontrol('Parent',hFig,'Style','text','String','Set a folder or load an image.',...
        'FontSize',7.5,'ForegroundColor',C.textD,'BackgroundColor',[0.08 0.10 0.15],...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 42],'Max',4);       y=y-18;

    % Results
    sLbl('RESULTS',y);                     y=y-62;
    hResults=uicontrol('Parent',hFig,'Style','text','String','---','FontSize',8.5,...
        'ForegroundColor',C.textW,'BackgroundColor',[0.08 0.10 0.15],...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 58],'Max',5);       y=y-18;

    % Defect colour legend
    sLbl('DEFECT LEGEND',y);               y=y-14;
    legD={'Holes',DC.Holes;'Discoloration',DC.Disco;'Deformation',DC.Deform};
    for li=1:3
        uipanel('Parent',hFig,'BackgroundColor',legD{li,2},'Units','pixels',...
            'Position',[12 y-1 11 10],'BorderType','none');
        uicontrol('Parent',hFig,'Style','text','String',legD{li,1},'FontSize',7.5,...
            'ForegroundColor',C.textW,'BackgroundColor',C.panel,...
            'HorizontalAlignment','left','Units','pixels',...
            'Position',[28 y-3 pnlW-32 14]);
        y=y-14;
    end

    % View details and reset buttons
    hBtnPage=uicontrol('Parent',hFig,'Style','pushbutton',...
        'String','  View Details  >','FontSize',9,'FontWeight','bold',...
        'ForegroundColor',C.textW,'BackgroundColor',[0.18 0.22 0.38],...
        'Units','pixels','Position',[10 32 pnlW-18 24],'Callback',@onTogglePage);
    set(hBtnPage,'Enable','off');
    uicontrol('Parent',hFig,'Style','pushbutton','String','  Reset',...
        'FontSize',9,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.28 0.12 0.12],...
        'Units','pixels','Position',[10 6 pnlW-18 24],'Callback',@onReset);

    % Restore last folder across sessions
    if exist(lastFolderFile,'file')
        try
            saved=load(lastFolderFile,'lastFolder');
            if isfield(saved,'lastFolder') && isfolder(saved.lastFolder)
                appData.datasetFolder=saved.lastFolder;
                scanDatasetFolder();
            end
        catch
        end
    end

    % Display area (right of left panel)
    dispX=pnlW+8; dispW=winW-pnlW-14; dispH=winH-54-8;

    % Page 1 — main view (original + result side by side)
    hPage1=uipanel('Parent',hFig,'BackgroundColor',C.bg,'Units','pixels',...
        'Position',[dispX 4 dispW dispH],'BorderType','none','Visible','on');
    axW=floor((dispW-14)/2); axH=dispH-44;
    hAxOrig=axes('Parent',hPage1,'Units','pixels','Position',[4 32 axW axH],...
        'Color',C.panel,'XColor',C.border,'YColor',C.border,...
        'XTick',[],'YTick',[],'Box','on');
    title(hAxOrig,'Uploaded Image','Color',C.textW,'FontSize',10);
    phT(hAxOrig,'Upload an image',C);
    hAxResult=axes('Parent',hPage1,'Units','pixels','Position',[axW+10 32 axW axH],...
        'Color',C.panel,'XColor',C.border,'YColor',C.border,...
        'XTick',[],'YTick',[],'Box','on');
    title(hAxResult,'Detection Result','Color',C.textW,'FontSize',10);
    phT(hAxResult,'Run detection to see results',C);
    uicontrol('Parent',hPage1,'Style','text','String','Original Image','FontSize',8,...
        'ForegroundColor',C.textD,'BackgroundColor',C.bg,'HorizontalAlignment','center',...
        'Units','pixels','Position',[4 14 axW 16]);
    uicontrol('Parent',hPage1,'Style','text','String','Defects Highlighted','FontSize',8,...
        'ForegroundColor',C.textD,'BackgroundColor',C.bg,'HorizontalAlignment','center',...
        'Units','pixels','Position',[axW+10 14 axW 16]);

    % Page 2 — pipeline detail view (5 sub-pages, 4x2 grid = 8 slots)
    hPage2=uipanel('Parent',hFig,'BackgroundColor',C.bg,'Units','pixels',...
        'Position',[dispX 4 dispW dispH],'BorderType','none','Visible','off');
    uipanel('Parent',hPage2,'BackgroundColor',[0.10 0.18 0.36],'Units','pixels',...
        'Position',[0 dispH-36 dispW 36],'BorderType','none');
    hPipeBanner=uicontrol('Parent',hPage2,'Style','text',...
        'String','STAGE 1 — SEGMENTATION',...
        'FontSize',9,'FontWeight','bold','ForegroundColor',[0.88 0.94 1.00],...
        'BackgroundColor',[0.10 0.18 0.36],'HorizontalAlignment','center',...
        'Units','pixels','Position',[0 dispH-32 dispW-172 28]);
    hBtnPipeNext=uicontrol('Parent',hPage2,'Style','pushbutton','String','Next  >',...
        'FontSize',8,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.22 0.30 0.50],'Units','pixels',...
        'Position',[dispW-168 dispH-32 84 26],'Callback',@onPipeNext);
    hBtnPipePrev=uicontrol('Parent',hPage2,'Style','pushbutton','String','<  Prev',...
        'FontSize',8,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.22 0.30 0.50],'Units','pixels',...
        'Position',[dispW-80 dispH-32 76 26],'Callback',@onPipePrev,'Enable','off');

    % Build 4-col x 2-row axes grid for pipeline slots
    nC=4; nR=2; pX=8; pY=6;
    pAreaH=dispH-44;
    pCW=floor((dispW-(nC+1)*pX)/nC);
    pCH=floor((pAreaH-(nR+1)*pY)/nR);
    hPipe=gobjects(nR,nC);
    for rr=1:nR
        for cc=1:nC
            px2=pX+(cc-1)*(pCW+pX); py2=pAreaH-rr*(pCH+pY)+2;
            hPipe(rr,cc)=axes('Parent',hPage2,'Units','pixels',...
                'Position',[px2 py2 pCW pCH],...
                'Color',C.panel,'XColor',C.border,'YColor',C.border,...
                'XTick',[],'YTick',[],'Box','on');
            title(hPipe(rr,cc),'---','Color',C.textD,'FontSize',7.5);
        end
    end
    hPipeHint=uicontrol('Parent',hPage2,'Style','text',...
        'String','Run detection first to populate this view.','FontSize',10,...
        'ForegroundColor',C.textD,'BackgroundColor',C.bg,'HorizontalAlignment','center',...
        'Units','pixels','Position',[0 dispH/2-12 dispW 24]);
    pipeData=[];

    % ── UI Helper Functions ───────────────────────────────────────────────

    function sLbl(txt,yy)
        uicontrol('Parent',hFig,'Style','text','String',txt,'FontSize',7.5,...
            'FontWeight','bold','ForegroundColor',C.textD,'BackgroundColor',C.panel,...
            'HorizontalAlignment','left','Units','pixels',...
            'Position',[12 yy pnlW-16 14]);
    end

    function phT(ax,txt,CC)
        text(ax,0.5,0.5,txt,'Color',CC.textD,'HorizontalAlignment','center',...
            'FontSize',9,'Units','normalized');
    end

    % Overlay a two-line subtitle bar at the BOTTOM INSIDE the image axes.
    % Uses normalized [0,1] units so it works regardless of image resolution.
    % Dark semi-opaque background makes text readable over any image content.
    function pt(ax, ttl, sub)
        title(ax,''); xlabel(ax,'');
        ax.XColor=C.border; ax.YColor=C.border; ax.XTick=[]; ax.YTick=[];
        text(ax, 0.5, 0.01, ...
            sprintf('%s\n%s', ttl, sub), ...
            'Units','normalized', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', ...
            'Color', C.textW, ...
            'FontSize', 7, ...
            'FontWeight', 'bold', ...
            'Interpreter', 'none', ...
            'BackgroundColor', [0.05 0.07 0.12], ...
            'EdgeColor', [0.25 0.30 0.45], ...
            'Margin', 4);
    end

    % Same as pt but the text uses a custom highlight colour (for status/defect labels)
    function ptClr(ax, ttl, sub, clr)
        title(ax,''); xlabel(ax,'');
        ax.XColor=C.border; ax.YColor=C.border; ax.XTick=[]; ax.YTick=[];
        text(ax, 0.5, 0.01, ...
            sprintf('%s\n%s', ttl, sub), ...
            'Units','normalized', ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', ...
            'Color', clr, ...
            'FontSize', 7, ...
            'FontWeight', 'bold', ...
            'Interpreter', 'none', ...
            'BackgroundColor', [0.05 0.07 0.12], ...
            'EdgeColor', clr * 0.6, ...
            'Margin', 4);
    end

    % ── Dataset Folder Helpers ────────────────────────────────────────────

    function scanDatasetFolder()
        if isempty(appData.datasetFolder) || ~isfolder(appData.datasetFolder)
            set(hListBox,'String',{'(no folder loaded)'},'Value',1);
            appData.datasetFiles={};
            return;
        end
        exts={'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff'};
        files={};
        for ei=1:numel(exts)
            d=dir(fullfile(appData.datasetFolder,exts{ei}));
            for di=1:numel(d); files{end+1}=d(di).name; end %#ok<AGROW>
        end
        if ~isempty(files), [files,~]=sort(files); end
        appData.datasetFiles=files;
        if isempty(files)
            set(hListBox,'String',{'(no images found)'},'Value',1);
            set(hStatus,'String','Folder has no images.','ForegroundColor',C.orange);
        else
            set(hListBox,'String',files,'Value',1);
            fp=appData.datasetFolder;
            if numel(fp)>34, fp=['...' fp(end-30:end)]; end
            set(hLblFolder,'String',fp,'ForegroundColor',C.cyan);
            set(hStatus,...
                'String',sprintf('%d image(s) found.\nClick one to load.',numel(files)),...
                'ForegroundColor',C.green);
        end
    end

    function loadImageByName(fn)
        fullp=fullfile(appData.datasetFolder,fn);
        img=safeRead(fullp);
        if isempty(img), return; end
        appData.img=img;
        cla(hAxPrev); imshow(img,'Parent',hAxPrev);
        cla(hAxOrig); imshow(img,'Parent',hAxOrig);
        title(hAxOrig,'Uploaded Image','Color',C.textW,'FontSize',10);
        cla(hAxResult);
        title(hAxResult,'Detection Result','Color',C.textW,'FontSize',10);
        phT(hAxResult,'Press Run Detection',C);
        dispName=fn;
        if numel(dispName)>34, dispName=['...' dispName(end-30:end)]; end
        set(hLblFile,'String',dispName,'ForegroundColor',C.textW);
        set(hBtnDetect,'Enable','on');
        set(hBtnPage,'Enable','off','String','  View Details  >');
        set(hStatus,...
            'String',sprintf('Loaded: %s\n%dx%d px',fn,size(img,2),size(img,1)),...
            'ForegroundColor',C.cyan);
        set(hResults,'String','---','ForegroundColor',C.textW);
        appData.currentPage=1; appData.pipePg=1;
        set(hPage1,'Visible','on'); set(hPage2,'Visible','off');
    end

    % ── Callbacks ────────────────────────────────────────────────────────

    function onBrowseFolder(~,~)
        startDir=appData.datasetFolder;
        if isempty(startDir) || ~isfolder(startDir), startDir=pwd; end
        chosen=uigetdir(startDir,'Select Dataset Folder');
        if isequal(chosen,0), return; end
        appData.datasetFolder=chosen;
        scanDatasetFolder();
        lastFolder=chosen;
        try save(lastFolderFile,'lastFolder'); catch; end
    end

    function onRefreshFolder(~,~)
        if isempty(appData.datasetFolder)
            set(hStatus,'String','No folder set yet.','ForegroundColor',C.orange);
            return;
        end
        scanDatasetFolder();
    end

    function onListSelect(~,~)
        files=get(hListBox,'String');
        idx  =get(hListBox,'Value');
        if isempty(files) || isequal(files,{'(no folder loaded)'}) || ...
           isequal(files,{'(no images found)'}), return; end
        if idx<1 || idx>numel(files), return; end
        loadImageByName(files{idx});
    end

    function onUpload(~,~)
        startDir = appData.datasetFolder;
        if isempty(startDir) || ~isfolder(startDir), startDir = pwd; end
        [fn,fp] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff','Images'},...
            'Select Glove Image', startDir);
        if isequal(fn,0), return; end
        img = safeRead(fullfile(fp,fn));
        if isempty(img), return; end
        appData.img = img;
        cla(hAxPrev); imshow(img,'Parent',hAxPrev);
        cla(hAxOrig); imshow(img,'Parent',hAxOrig);
        title(hAxOrig,'Uploaded Image','Color',C.textW,'FontSize',10);
        cla(hAxResult);
        title(hAxResult,'Detection Result','Color',C.textW,'FontSize',10);
        phT(hAxResult,'Press Run Detection',C);
        dispName = fn;
        if numel(dispName) > 34, dispName = ['...' dispName(end-30:end)]; end
        set(hLblFile,'String',dispName,'ForegroundColor',C.textW);
        set(hBtnDetect,'Enable','on');
        set(hBtnPage,'Enable','off','String','  View Details  >');
        set(hStatus,'String',sprintf('Loaded: %s\n%dx%d px',fn,size(img,2),size(img,1)),...
            'ForegroundColor',C.cyan);
        set(hResults,'String','---');
        appData.currentPage = 1; appData.pipePg = 1;
        set(hPage1,'Visible','on'); set(hPage2,'Visible','off');
    end

    function onDetect(~,~)
        if isempty(appData.img), return; end
        set(hBtnDetect,'Enable','off'); drawnow;
        img=appData.img;

        set(hStatus,'String','Stage 1: Segmenting glove...','ForegroundColor',C.orange); drawnow;
        [gloveMask, gloveMaskFilled, imgGray, bgType] = segmentGlove(img);

        set(hStatus,'String',sprintf('Detecting holes... [BG:%s]',bgType),...
            'ForegroundColor',C.orange); drawnow;
        [holeMask, holesOK] = detectHoles(img, gloveMask);

        set(hStatus,'String','Detecting discoloration...','ForegroundColor',C.orange); drawnow;
        [discoMask, discoOK] = detectDiscoloration(img, gloveMaskFilled, holeMask, gloveMask);

        set(hStatus,'String','Detecting deformation...','ForegroundColor',C.orange); drawnow;
        [deformMask, deformOK] = detectDeformation(img, gloveMask);

        defNames={}; defMasks={}; defColors={};
        if holesOK,  defNames{end+1}='Holes';        defMasks{end+1}=holeMask;   defColors{end+1}=DC.Holes;  end
        if discoOK,  defNames{end+1}='Discoloration';defMasks{end+1}=discoMask;  defColors{end+1}=DC.Disco;  end
        if deformOK, defNames{end+1}='Deformation';  defMasks{end+1}=deformMask; defColors{end+1}=DC.Deform; end

        cla(hAxResult); hold(hAxResult,'on');
        imshow(img,'Parent',hAxResult);
        set(hAxResult,'XLim',[0.5 size(img,2)+0.5],'YLim',[0.5 size(img,1)+0.5]);
        for d=1:numel(defMasks), drawCircles(hAxResult,defMasks{d},defColors{d}); end
        hold(hAxResult,'off');

        if isempty(defNames)
            tStr='PASS  —  No Defects Detected'; tClr=C.green;
            set(hStatus,'String',sprintf('Done [BG:%s]. PASS.',bgType),'ForegroundColor',C.green);
            set(hResults,'String','PASS','ForegroundColor',C.green);
        else
            tStr=strjoin(defNames,',  '); tClr=C.orange;
            set(hStatus,'String',sprintf('Done [BG:%s].',bgType),'ForegroundColor',C.cyan);
            set(hResults,'String',['Detected:' sprintf('\n%s',defNames{:})],...
                'ForegroundColor',C.orange);
        end
        title(hAxResult,tStr,'Color',tClr,'FontSize',10,'FontWeight','bold');
        set(hBtnDetect,'Enable','on');

        pipeData=struct('img',img,'imgGray',imgGray,...
            'gloveMask',gloveMask,'gloveMaskFilled',gloveMaskFilled,'bgType',bgType,...
            'holeMask',holeMask,'discoMask',discoMask,...
            'deformMask',deformMask,'defNames',{defNames});
        appData.pipePg=1; set(hPipeHint,'Visible','off');
        renderPipePage(1);
        set(hBtnPage,'Enable','on'); drawnow;
    end

    function onTogglePage(~,~)
        if appData.currentPage==1
            set(hPage1,'Visible','off'); set(hPage2,'Visible','on');
            set(hBtnPage,'String','  < Back to Main'); appData.currentPage=2;
        else
            set(hPage2,'Visible','off'); set(hPage1,'Visible','on');
            set(hBtnPage,'String','  View Details  >'); appData.currentPage=1;
        end
    end

    function onPipeNext(~,~)
        appData.pipePg=min(appData.pipePg+1,5); renderPipePage(appData.pipePg);
        set(hBtnPipePrev,'Enable','on');
        if appData.pipePg==5, set(hBtnPipeNext,'Enable','off');
        else,                 set(hBtnPipeNext,'Enable','on'); end
    end

    function onPipePrev(~,~)
        appData.pipePg=max(appData.pipePg-1,1); renderPipePage(appData.pipePg);
        set(hBtnPipeNext,'Enable','on');
        if appData.pipePg==1, set(hBtnPipePrev,'Enable','off');
        else,                 set(hBtnPipePrev,'Enable','on'); end
    end

    function onReset(~,~)
        appData.img=[]; appData.currentPage=1; appData.pipePg=1; pipeData=[];
        for ax2=[hAxPrev,hAxOrig,hAxResult]; cla(ax2); end
        title(hAxOrig,'Uploaded Image','Color',C.textW,'FontSize',10);
        title(hAxResult,'Detection Result','Color',C.textW,'FontSize',10);
        phT(hAxOrig,'Select from list or load file',C);
        phT(hAxResult,'Run detection to see results',C);
        set(hLblFile,'String','No image loaded','ForegroundColor',C.textD);
        set(hBtnDetect,'Enable','off');
        set(hBtnPage,'Enable','off','String','  View Details  >');
        if ~isempty(appData.datasetFolder)
            set(hStatus,'String',sprintf('Ready. %d image(s) in folder.',...
                numel(appData.datasetFiles)),'ForegroundColor',C.textD);
        else
            set(hStatus,'String','Set a folder or load an image.','ForegroundColor',C.textD);
        end
        set(hResults,'String','---','ForegroundColor',C.textW);
        set(hPage1,'Visible','on'); set(hPage2,'Visible','off');
        for rr2=1:nR
            for cc2=1:nC
                cla(hPipe(rr2,cc2));
                title(hPipe(rr2,cc2),'---','Color',C.textD,'FontSize',7.5);
                xlabel(hPipe(rr2,cc2),'');
            end
        end
        set(hPipeHint,'Visible','on');
        set(hBtnPipeNext,'Enable','on'); set(hBtnPipePrev,'Enable','off');
    end

    % =====================================================================
    %  PIPELINE PAGE RENDERER  (5 pages x 8 slots)
    % =====================================================================

    function s=logical2onoff(v); if v, s='on'; else, s='off'; end; end

    function renderPipePage(pg)
        if isempty(pipeData), return; end
        for rr2=1:nR
            for cc2=1:nC
                cla(hPipe(rr2,cc2));
                xlabel(hPipe(rr2,cc2),'');
            end
        end

        img2    = pipeData.img;
        gM      = pipeData.gloveMask;
        gMF     = pipeData.gloveMaskFilled;
        hM      = pipeData.holeMask;
        dM      = pipeData.discoMask;
        dfM     = pipeData.deformMask;
        imgD    = im2double(img2);
        defNames= pipeData.defNames;
        bgType  = pipeData.bgType;

        banners={...
            sprintf('PAGE 1 — SEGMENTATION  |  BG: %s  |  Tri-Mask Strategy  |  Steps 1-8',upper(bgType)),...
            'PAGE 2 — HOLE DETECTION  |  Fill-comparison: enclosed void = hole',...
            'PAGE 3 — DISCOLORATION  |  CIELAB MAD > 3.0σ  (holes excluded from zone)',...
            'PAGE 4 — DEFORMATION  |  Column-wise fingertip height profile',...
            'PAGE 5 — COMBINED RESULT  |  All defects overlaid + final output'};
        set(hPipeBanner,'String',banners{pg});
        set(hBtnPipePrev,'Enable',logical2onoff(pg>1));
        set(hBtnPipeNext,'Enable',logical2onoff(pg<5));

        % Show a single defect detection result with ellipse markers
        function showDefectResult(ax,mask,clr,name)
            cla(ax); hold(ax,'on'); imshow(img2,'Parent',ax);
            set(ax,'XLim',[0.5 size(img2,2)+0.5],'YLim',[0.5 size(img2,1)+0.5]);
            if any(mask(:)), drawCircles(ax,mask,clr); end
            hold(ax,'off');
            if any(mask(:))
                ptClr(ax, [name ' — DEFECT FOUND'], 'Ellipse marks confirmed defect location', clr);
            else
                pt(ax, [name ' — NOT DETECTED'], 'No defect of this type found in glove');
            end
        end

        % Hide an unused grid slot (blank dark panel)
        function hideSlot(ax)
            cla(ax); ax.Color=C.bg; ax.XColor=C.bg; ax.YColor=C.bg;
            ax.Box='off'; ax.XTick=[]; ax.YTick=[];
            title(ax,''); xlabel(ax,'');
        end

        % -----------------------------------------------------------------
        if pg==1  % SEGMENTATION — all 8 slots used
        % -----------------------------------------------------------------
            hsvI=rgb2hsv(img2);
            H2=hsvI(:,:,1); S2=hsvI(:,:,2); V2=hsvI(:,:,3);
            [r2,c2]=size(H2);
            bw2=20;
            bH2=sampBorder(H2,bw2); bS2=sampBorder(S2,bw2); bV2=sampBorder(V2,bw2);
            bgH2=median(bH2); bgS2=median(bS2); bgV2=median(bV2);
            hueDist2=min(abs(H2-bgH2),1-abs(H2-bgH2));

            % Re-derive tri-masks locally to match segmentGlove logic per bg type
            switch bgType
                case 'dark'
                    vT2   = max(graythresh(V2)*0.80, 0.22);
                    mA    = (V2 > vT2);
                    mB    = (S2 > 0.22) & (V2 > 0.16);
                    mC    = (hueDist2 + 0.5*abs(S2-bgS2)) > 0.09;
                case 'blue'
                    sThr2 = max(bgS2*0.50, 0.14);
                    mA    = (S2 < sThr2) & (V2 > 0.32);
                    mB    = (hueDist2 > 0.12) & (V2 > 0.28);
                    mC    = (S2 < 0.28) & (V2 > 0.50);
                case 'warm'
                    sThr2 = max(bgS2*0.55, 0.14);
                    mA    = (S2 < sThr2) & (V2 > 0.38);
                    mB    = (hueDist2 + 0.80*abs(S2-bgS2)) > 0.14;
                    mC    = (S2 < 0.28) & (V2 > 0.50);
                otherwise
                    hueMap2 = hueDist2 + 0.5*abs(S2-bgS2);
                    mA    = (hueMap2 > 0.09);
                    mB    = (V2 > max(graythresh(V2)*0.80, 0.22));
                    mC    = (S2 < 0.28) & (V2 > 0.50);
            end

            % Slot (1,1) — original image
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1), 'Step 1: Original RGB Image', ...
                'Input image — baseline for all processing stages');

            % Slot (1,2) — 20px border strip highlighted for BG sampling
            borderVis=imgD*0.25;
            borderMask=false(r2,c2);
            borderMask(1:bw2,:)=true; borderMask(end-bw2+1:end,:)=true;
            borderMask(:,1:bw2)=true; borderMask(:,end-bw2+1:end)=true;
            for ch=1:3
                sl=borderVis(:,:,ch); chSlice=imgD(:,:,ch);
                sl(borderMask)=chSlice(borderMask); borderVis(:,:,ch)=sl;
            end
            redCh=borderVis(:,:,1);
            redCh(borderMask)=min(1,redCh(borderMask)*0.7+0.4);
            borderVis(:,:,1)=redCh;
            imshow(borderVis,'Parent',hPipe(1,2));
            ptClr(hPipe(1,2), 'Step 2: Border Sampling Strip (20px)', ...
                sprintf('BG hue=%.2f  sat=%.2f  val=%.2f  | Detected type: %s', ...
                bgH2, bgS2, bgV2, upper(bgType)), [1.00 0.60 0.60]);

            % Slot (1,3) — Mask A: primary separator for this BG type
            imshow(mA,'Parent',hPipe(1,3));
            ptClr(hPipe(1,3), 'Step 3: Mask A — Primary Separator', ...
                'White regions = glove candidate pixels', [0.80 1.00 0.80]);

            % Slot (1,4) — Mask B: fallback / stain catcher
            imshow(mB,'Parent',hPipe(1,4));
            ptClr(hPipe(1,4), 'Step 4: Mask B — Secondary / Fallback', ...
                'Catches stained or discoloured glove patches', [0.80 0.85 1.00]);

            % Slot (2,1) — Mask C: low-sat bright glove catch
            imshow(mC,'Parent',hPipe(2,1));
            pt(hPipe(2,1), 'Step 5: Mask C — Tertiary Catch', ...
                'Targets low-saturation bright pixels');

            % Slot (2,2) — union of all three masks (colour-coded)
            combVis=zeros(r2,c2,3);
            combVis(:,:,2)=double(mA)*0.8;  % green = A
            combVis(:,:,3)=double(mB)*0.8;  % blue  = B
            combVis(:,:,1)=double(mC)*0.8;  % red   = C
            allThree=mA&mB&mC;
            for ch=1:3; sl=combVis(:,:,ch); sl(allThree)=1.0; combVis(:,:,ch)=sl; end
            imshow(combVis,'Parent',hPipe(2,2));
            ptClr(hPipe(2,2), 'Step 6: Combined Raw Mask  (A | B | C)', ...
                'Green=A  Blue=B  Red=C  White=all three agree', [0.95 0.95 0.70]);

            % Slot (2,3) — tight gloveMask after morphology + largest CC + wrist cut
            maskVis=imgD*0.25;
            for ch=1:3
                sl=maskVis(:,:,ch); chSlice=imgD(:,:,ch);
                sl(gM)=chSlice(gM); maskVis(:,:,ch)=sl;
            end
            holePreview=imfill(imclose(gM,strel('disk',3)),'holes') & ~gM;
            maskVis(:,:,1)=maskVis(:,:,1).*double(~holePreview);
            maskVis(:,:,2)=maskVis(:,:,2).*double(~holePreview)+double(holePreview)*0.85;
            maskVis(:,:,3)=maskVis(:,:,3).*double(~holePreview)+double(holePreview)*0.85;
            imshow(maskVis,'Parent',hPipe(2,3));
            ptClr(hPipe(2,3), 'Step 7: Tight Glove Mask  (cyan = enclosed voids)', ...
                'After morphology cleanup + largest CC + wrist cut', [0.60 0.90 1.00]);

            % Slot (2,4) — filled gloveMask used as discoloration analysis zone
            filledOnly=gMF & ~gM;
            fillVis=imgD*0.40;
            for ch=1:3
                sl=fillVis(:,:,ch); chSlice=imgD(:,:,ch);
                sl(gM)=chSlice(gM);
                sl(filledOnly)=DC.Disco(ch)*0.65;
                fillVis(:,:,ch)=sl;
            end
            imshow(fillVis,'Parent',hPipe(2,4));
            ptClr(hPipe(2,4), 'Step 8: Filled Glove Mask  (orange = extended zone)', ...
                'imclose(disk18) + imfill — wider zone for discoloration', [1.00 0.75 0.30]);

        % -----------------------------------------------------------------
        elseif pg==2  % HOLE DETECTION — slots 1-6 used, 7-8 hidden
        % -----------------------------------------------------------------
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1), 'Step 1: Original Image', 'Input to hole detector');

            % Show mask as a cyan tint over the dimmed original image
            maskVis = imgD * 0.3;
            for ch = 1:3
                sl = maskVis(:,:,ch);
                sl(gM) = imgD(find(gM) + (ch-1)*numel(gM));  % restore glove pixels
                maskVis(:,:,ch) = sl;
            end
            imshow(maskVis, 'Parent', hPipe(1,2));

            pt(hPipe(1,2), 'Step 2: Tight Glove Mask', ...
                'Topology analysis requires the unfilled tight mask');

            % imclose seals micro-gaps but does NOT bridge open finger gaps
            closedM=imclose(gM,strel('disk',3));
            imshow(closedM,'Parent',hPipe(1,3));
            pt(hPipe(1,3), 'Step 3: Morphological Close  (disk r=3)', ...
                'Seals tiny gaps — finger gaps remain open');

            % imfill: finger gaps touch edge → stay open; holes → get filled
            filledM=imfill(closedM,'holes');
            imshow(filledM,'Parent',hPipe(1,4));
            pt(hPipe(1,4), 'Step 4: Flood Fill  (imfill holes)', ...
                'Enclosed holes filled | Open finger gaps unchanged');

            % Difference = enclosed voids only
            diffM=filledM & ~gM;
            diffVis=imgD*0.4;
            for ch=1:3; sl=diffVis(:,:,ch); sl(diffM)=DC.Holes(ch); diffVis(:,:,ch)=sl; end
            imshow(diffVis,'Parent',hPipe(2,1));
            pt(hPipe(2,1), 'Step 5: Filled minus Tight Mask', ...
                sprintf('Highlighted regions = %d enclosed void pixel(s)', nnz(diffM)));

            showDefectResult(hPipe(2,2), hM, DC.Holes, 'Holes');

            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));

        % -----------------------------------------------------------------
        elseif pg==3  % DISCOLORATION — slots 1-6 used, 7-8 hidden
        % -----------------------------------------------------------------
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1), 'Step 1: Original Image', 'Input to discoloration detector');

            % Build the safe analysis zone (eroded mask minus hole buffer)
            safeShow=imerode(gM,strel('disk',5));
            holeBuffer=[];
            if any(hM(:))
                holeBuffer=imdilate(hM,strel('disk',15));
                safeShow=safeShow & ~holeBuffer;
            end
            if ~any(safeShow(:)), safeShow=gMF; end
            zoneVis=imgD*0.35;
            for ch=1:3
                sl=zoneVis(:,:,ch); chSlice=imgD(:,:,ch);
                sl(safeShow)=chSlice(safeShow)*0.7+0.3*(ch==2)*0.5;
                if ~isempty(holeBuffer)
                    excl=holeBuffer & gMF;
                    sl(excl)=0.55*(ch==1);
                end
                zoneVis(:,:,ch)=sl;
            end
            imshow(zoneVis,'Parent',hPipe(1,2));
            if any(hM(:))
                ptClr(hPipe(1,2), 'Step 2: Analysis Zone  (red = excluded near hole)', ...
                    'Eroded glove mask minus 15px hole buffer', [1.00 0.50 0.50]);
            else
                pt(hPipe(1,2), 'Step 2: Safe Analysis Zone', ...
                    'Eroded glove mask — avoids edge noise');
            end

            % CIELAB a* and b* channels show colour deviation
            labI=rgb2lab(imgD); A=labI(:,:,2); B=labI(:,:,3);
            imshow(mat2gray(A),'Parent',hPipe(1,3));
            pt(hPipe(1,3), 'Step 3: CIELAB  a*  Channel', ...
                'Green-to-Red axis — colour shift along this axis');

            imshow(mat2gray(B),'Parent',hPipe(1,4));
            pt(hPipe(1,4), 'Step 4: CIELAB  b*  Channel', ...
                'Blue-to-Yellow axis — colour shift along this axis');

            % Re-derive MAD heatmap to match actual detector logic
            safeG=imerode(gM,strel('disk',5));
            if ~any(safeG(:)), safeG=gM; end
            if any(hM(:)), safeG=safeG & ~imdilate(hM,strel('disk',15)); end
            if ~any(safeG(:)), safeG=gMF; end
            gA=A(safeG); gB=B(safeG);
            devA=abs(A-median(gA))/(max(iqr(gA),1.0)*1.4826);
            devB=abs(B-median(gB))/(max(iqr(gB),1.0)*1.4826);
            devMap=sqrt(devA.^2+devB.^2).*double(safeG);
            dNorm=devMap./(max(devMap(:))+eps);
            heatR=min(1,dNorm*2); heatG=max(0,min(1,dNorm*2-0.5)); heatB=max(0,1-dNorm*2);
            heatImg=cat(3,heatR,heatG,heatB).*double(gM);
            if any(dM(:))
                for ch=1:3; sl=heatImg(:,:,ch); sl(dM)=DC.Disco(ch); heatImg(:,:,ch)=sl; end
            end
            imshow(heatImg,'Parent',hPipe(2,1));
            pt(hPipe(2,1), 'Step 5: MAD Colour Deviation Heatmap', ...
                'Blue = normal | Red = high deviation | Orange = detected stain');

            showDefectResult(hPipe(2,2), dM, DC.Disco, 'Discoloration');

            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));

        % -----------------------------------------------------------------
        elseif pg==4  % DEFORMATION — slots 1-6 used, 7-8 hidden
        % -----------------------------------------------------------------
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1), 'Step 1: Original Image', 'Input to deformation detector');

            % Show mask as a cyan tint over the dimmed original image
            maskVis = imgD * 0.3;
            for ch = 1:3
                sl = maskVis(:,:,ch);
                sl(gM) = imgD(find(gM) + (ch-1)*numel(gM));  % restore glove pixels
                maskVis(:,:,ch) = sl;
            end
            imshow(maskVis, 'Parent', hPipe(1,2));
            pt(hPipe(1,2), 'Step 2: Tight Glove Mask', 'Shape analysis uses the tight mask');

            % Highlight the finger analysis zone (top 30% of bounding box)
            fingerVis=imgD*0.4; rp4=regionprops(gM,'BoundingBox');
            if ~isempty(rp4)
                bb4=rp4(1).BoundingBox; r4=size(gM,1);
                fBot=min(r4,round(bb4(2)+bb4(4)*0.30)); fTop=max(1,round(bb4(2)));
                fingerReg=false(size(gM)); fingerReg(fTop:fBot,:)=gM(fTop:fBot,:);
                for ch=1:3; sl=fingerVis(:,:,ch);
                    sl(fingerReg)=0.4*sl(fingerReg)+0.6*(ch==2)*0.6;
                    fingerVis(:,:,ch)=sl;
                end
            end
            imshow(fingerVis,'Parent',hPipe(1,3));
            pt(hPipe(1,3), 'Step 3: Finger Analysis Zone  (top 30% of bbox)', ...
                'Palm area is excluded from deformation analysis');

            % Plot column-wise fingertip height profile with threshold lines
            ax9=hPipe(1,4); cla(ax9); hold(ax9,'on');
            ax9.Color=[0.07 0.09 0.14]; ax9.XColor=C.textD; ax9.YColor=C.textD;
            ax9.Box='on'; ax9.FontSize=5.5;
            rp9=regionprops(gM,'BoundingBox');
            if ~isempty(rp9)
                bb9=rp9(1).BoundingBox; rows9=size(gM,1); nCols9=size(gM,2);
                topR9=max(1,round(bb9(2))); botR9=min(rows9,round(bb9(2)+bb9(4)*0.78));
                cL9=max(1,round(bb9(1))); cR9=min(nCols9,round(bb9(1)+bb9(3)));
                fReg9=gM(topR9:botR9,:); tipP9=zeros(1,nCols9); gCM9=false(1,nCols9);
                for c9=cL9:cR9
                    i9=find(fReg9(:,c9),1,'first');
                    if ~isempty(i9), tipP9(c9)=botR9-(topR9+i9-1); gCM9(c9)=true; end
                end
                tipS9=imgaussflit_safe(tipP9,4); tipS9(~gCM9)=0; xx9=find(gCM9);
                % Collect plot handles so the legend only lists what was drawn
                hLeg9=[]; legStr9={};
                h1=plot(ax9,xx9,tipS9(xx9),'-','Color',[0.35 0.65 1.0],'LineWidth',1.5);
                hLeg9(end+1)=h1; legStr9{end+1}='Tip profile';
                maxH9=max(tipS9(xx9)); if maxH9<1, maxH9=1; end
                validC9=tipS9(xx9); medH9=median(validC9(validC9>maxH9*0.35));
                thr9=medH9*1.25;
                h2=plot(ax9,[cL9 cR9],[medH9 medH9],'--','Color',[0.55 0.55 0.55],'LineWidth',1.0);
                hLeg9(end+1)=h2; legStr9{end+1}='Median H';
                h3=plot(ax9,[cL9 cR9],[thr9 thr9],':','Color',[1.0 0.55 0.15],'LineWidth',1.5);
                hLeg9(end+1)=h3; legStr9{end+1}='x1.25 thr';
                if any(dfM(:))
                    dfCols=any(dfM,1); xcols=find(dfCols & gCM9);
                    if ~isempty(xcols)
                        h4=fill(ax9,[xcols(1) xcols(end) xcols(end) xcols(1)],...
                            [0 0 maxH9*1.15 maxH9*1.15],...
                            DC.Deform,'FaceAlpha',0.20,'EdgeColor',DC.Deform,'LineWidth',1);
                        hLeg9(end+1)=h4; legStr9{end+1}='Deform zone';
                    end
                end
                ax9.XLim=[cL9 cR9]; ax9.YLim=[0 maxH9*1.18];
                % Only pass handles that were actually drawn — prevents the warning
                legend(ax9, hLeg9, legStr9, ...
                    'TextColor',[0.7 0.7 0.7],'Color',[0.09 0.11 0.17],...
                    'FontSize',5,'Location','southeast','Box','off');
            end
            hold(ax9,'off');
            if any(dfM(:))
                ptClr(ax9, 'Step 4: Fingertip Height Profile — DEFORMATION FOUND', ...
                    'A finger peak exceeds median height by more than 25%', DC.Deform);
            else
                pt(ax9, 'Step 4: Fingertip Height Profile', ...
                    'Blue=profile  |  Grey=median  |  Orange=x1.25 threshold');
            end

            % Deformation mask overlay
            defVis=imgD*0.4;
            if any(dfM(:))
                for ch=1:3; sl=defVis(:,:,ch);
                    sl(dfM)=0.3*sl(dfM)+0.7*DC.Deform(ch); defVis(:,:,ch)=sl;
                end
            end
            imshow(defVis,'Parent',hPipe(2,1));
            pt(hPipe(2,1), 'Step 5: Deformation Pixel Mask', ...
                'Highlighted = finger(s) exceeding the height threshold');

            showDefectResult(hPipe(2,2), dfM, DC.Deform, 'Deformation');

            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));

        % -----------------------------------------------------------------
        else  % pg==5 — COMBINED RESULT
        % -----------------------------------------------------------------
            defList ={hM,dM,dfM};
            defCols ={DC.Holes,DC.Disco,DC.Deform};
            defLbls ={'Holes','Discoloration','Deformation'};
            axList  ={hPipe(1,1),hPipe(1,2),hPipe(1,3)};

            % Show each defect type individually in first three slots
            for di=1:3
                cla(axList{di}); hold(axList{di},'on');
                imshow(img2,'Parent',axList{di});
                set(axList{di},'XLim',[0.5 size(img2,2)+0.5],'YLim',[0.5 size(img2,1)+0.5]);
                if any(defList{di}(:))
                    drawCircles(axList{di},defList{di},defCols{di});
                    ptClr(axList{di}, ['Step ' num2str(di) ': ' defLbls{di} ' — FOUND'], ...
                        'Ellipse marks confirmed defect location', defCols{di});
                else
                    pt(axList{di}, ['Step ' num2str(di) ': ' defLbls{di}], ...
                        'Not detected in this image');
                end
                hold(axList{di},'off');
            end

            hideSlot(hPipe(1,4));

            % All defect masks combined (colour-blended overlay)
            combVis=imgD*0.38;
            for d2=1:3
                if any(defList{d2}(:))
                    for ch=1:3; sl=combVis(:,:,ch);
                        sl(defList{d2})=0.30*sl(defList{d2})+0.70*defCols{d2}(ch);
                        combVis(:,:,ch)=sl;
                    end
                end
            end
            cand11=hM|dM|dfM;
            CC11=bwconncomp(imdilate(cand11,strel('disk',4)));
            nDef11=nnz([any(hM(:)) any(dM(:)) any(dfM(:))]);
            imshow(combVis,'Parent',hPipe(2,1));
            pt(hPipe(2,1), 'Step 4: All Defect Masks Overlaid', ...
                sprintf('%d defect type(s) detected  |  %d distinct region(s)', nDef11, CC11.NumObjects));

            % Final result with all ellipse markers
            cla(hPipe(2,2)); hold(hPipe(2,2),'on');
            imshow(img2,'Parent',hPipe(2,2));
            set(hPipe(2,2),'XLim',[0.5 size(img2,2)+0.5],'YLim',[0.5 size(img2,1)+0.5]);
            for d2=1:3
                if any(defList{d2}(:)), drawCircles(hPipe(2,2),defList{d2},defCols{d2}); end
            end
            hold(hPipe(2,2),'off');
            if isempty(defNames)
                ptClr(hPipe(2,2), 'Step 5: FINAL RESULT — PASS', ...
                    'All detectors within normal range — glove is acceptable', C.green);
            else
                ptClr(hPipe(2,2), ['Step 5: FINAL RESULT — FAIL  (' strjoin(defNames,', ') ')'], ...
                    'Ellipses show locations of confirmed defects', C.orange);
            end

            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));
        end
    end % renderPipePage

end % GDDS


% =========================================================================
%  UTILITY FUNCTIONS
% =========================================================================

function img = safeRead(path)
    img=[];
    try
        raw=imread(path);
        if ndims(raw)==2, raw=cat(3,raw,raw,raw); end
        if size(raw,3)==4, raw=raw(:,:,1:3); end
        img=raw;
    catch, errordlg('Cannot read image.','Error');
    end
end

% Collect border pixels from a 2-D channel (used for BG statistics)
function bPx = sampBorder(ch, bw)
    bPx=[reshape(ch(1:bw,:),[],1);
         reshape(ch(end-bw+1:end,:),[],1);
         reshape(ch(:,1:bw),[],1);
         reshape(ch(:,end-bw+1:end),[],1)];
end


% =========================================================================
%  STAGE 1 — GLOVE SEGMENTATION
%
%  Background classification from 20-px border statistics:
%    blue    — sat>0.28, H in blue band (0.48–0.78)
%    warm    — sat>0.18, H in warm band (<0.15 or >0.88)
%    dark    — median V < 0.28  (checked AFTER blue/warm to separate navy)
%    colored — other saturated colour
%    neutral — low saturation (white / grey / light)
%
%  Adaptive masks per BG type (see switch block for thresholds).
%  Sanity check: if fg ratio < 3% or > 92%, falls back to Otsu on grayscale.
%
%  Returns:
%    gloveMask       — tight mask; used for holes + deformation
%    gloveMaskFilled — aggressively closed + imfill; wider zone for discoloration
%    imgGray         — grayscale for display
%    bgType          — string label
% =========================================================================
function [gloveMask, gloveMaskFilled, imgGray, bgType] = segmentGlove(img)
    imgGray = rgb2gray(img);
    hsvImg  = rgb2hsv(img);
    H = hsvImg(:,:,1); S = hsvImg(:,:,2); V = hsvImg(:,:,3);
    [rows, cols] = size(H);
    bw = 20;

    borderH = sampBorder(H, bw);
    borderS = sampBorder(S, bw);
    borderV = sampBorder(V, bw);
    bgHue = median(borderH);
    bgSat = median(borderS);
    bgVal = median(borderV);

    % Blue/warm must be checked before dark: navy is both dark AND blue-saturated.
    % Pure black is dark AND low-saturation — that is the only true "dark" case.
    if bgSat > 0.28 && bgHue >= 0.48 && bgHue <= 0.78
        bgType = 'blue';
    elseif bgSat > 0.18 && (bgHue < 0.15 || bgHue > 0.88)
        bgType = 'warm';
    elseif bgVal < 0.28
        bgType = 'dark';
    elseif bgSat > 0.20
        bgType = 'colored';
    else
        bgType = 'neutral';
    end

    hueDist = min(abs(H - bgHue), 1 - abs(H - bgHue));

    switch bgType
        case 'dark'
            % Otsu-scaled V-threshold; saturation gate catches dimmer wrist areas
            vT      = max(graythresh(V) * 0.80, 0.22);
            rawMask = (V > vT) | (S > 0.22 & V > 0.16);

        case 'blue'
            % Adaptive S-threshold separates white glove (S≈0.10) from navy (S≈0.60)
            sThr  = max(bgSat * 0.50, 0.14);
            maskA = (S < sThr) & (V > 0.32);
            maskB = (hueDist > 0.12) & (V > 0.28);  % hue fallback for stained patches
            rawMask = (maskA | maskB) & (V > 0.12);

        case 'warm'
            % White glove has near-zero S; wood has medium S — S-threshold is key
            sThr  = max(bgSat * 0.55, 0.14);
            maskA = (S < sThr) & (V > 0.38);
            maskB = (hueDist + 0.80 * abs(S - bgSat)) > 0.14;
            rawMask = (maskA | maskB) & (V > 0.12);

        otherwise  % colored / neutral
            hueMap  = hueDist + 0.5 * abs(S - bgSat);
            maskA   = (hueMap > 0.09);
            maskB   = (S < 0.28) & (V > 0.50);
            rawMask = (maskA | maskB) & (V > 0.18);
    end

    % Fallback to Otsu on grayscale if primary mask is grossly over/under-segmented
    fgRatio = sum(rawMask(:)) / numel(rawMask);
    if fgRatio < 0.03 || fgRatio > 0.92
        grayD = im2double(imgGray);
        gT    = graythresh(grayD);
        if bgVal < 0.45
            rawMask = grayD > gT;
        else
            rawMask = grayD < (1 - gT * 0.5);
        end
    end

    rawMask = imclose(rawMask, strel('disk', 3));
    rawMask = imopen(rawMask,  strel('disk', 2));

    % Keep only the largest connected component (main glove body)
    CC = bwconncomp(rawMask);
    if CC.NumObjects == 0
        gloveMask       = true(rows, cols);
        gloveMaskFilled = gloveMask;
        return;
    end
    [~, idx] = max(cellfun(@numel, CC.PixelIdxList));
    tightMask = false(rows, cols);
    tightMask(CC.PixelIdxList{idx}) = true;

    % Wrist cut — locate palm-to-wrist narrowing and trim below it
    rp = regionprops(tightMask, 'BoundingBox');
    if ~isempty(rp)
        bb          = rp(1).BoundingBox;
        gTop        = max(1,   round(bb(2)));
        gBot        = min(rows, round(bb(2) + bb(4)));
        gH          = gBot - gTop + 1;
        searchStart = round(gTop + gH * 0.50);
        rowW        = sum(tightMask(searchStart:gBot, :), 2);
        cutRow      = round(gTop + gH * 0.88);
        if numel(rowW) > 10 && max(rowW) > 0
            smoothW = imgaussflit_safe(double(rowW), 5);
            [palmW, palmIdx] = max(smoothW);
            narrowIdx = find(smoothW(palmIdx:end) < palmW * 0.60, 1, 'first');
            if ~isempty(narrowIdx)
                cutRow = searchStart + palmIdx + narrowIdx - 2;
                cutRow = max(cutRow, round(gTop + gH * 0.70));
                cutRow = min(cutRow, gBot);
            end
        end
        tightMask(cutRow:end, :) = false;
    end

    % Finger zone cleanup — erode+dilate to remove thin noise between fingers
    rp2 = regionprops(tightMask, 'BoundingBox');
    fingerZoneBot = rows; gloveTop = 1;
    if ~isempty(rp2)
        bb2           = rp2(1).BoundingBox;
        gloveTop      = max(1,   round(bb2(2)));
        gloveBot      = min(rows, round(bb2(2) + bb2(4)));
        fingerZoneBot = min(rows, round(gloveTop + (gloveBot - gloveTop) * 0.72));
    end
    fingerZoneMask = false(rows, cols);
    fingerZoneMask(gloveTop:fingerZoneBot, :) = true;
    fingerPart     = tightMask & fingerZoneMask;
    palmPart       = tightMask & ~fingerZoneMask;
    fingerEroded   = imerode(fingerPart,   strel('disk', 7));
    fingerRestored = imdilate(fingerEroded, strel('disk', 4));
    CC2 = bwconncomp(fingerRestored);
    cleanFinger = false(rows, cols);
    for kk = 1:CC2.NumObjects
        if numel(CC2.PixelIdxList{kk}) >= 600
            cleanFinger(CC2.PixelIdxList{kk}) = true;
        end
    end
    tightMask = cleanFinger | palmPart;
    tightMask = imclose(tightMask, strel('disk', 3));
    tightMask = imerode(tightMask,  strel('disk', 3));

    gloveMask = tightMask;

    % Filled mask — aggressive close + imfill so discoloration detector
    % can sample patches that the HSV gate excluded from the tight mask
    filledTemp = imclose(tightMask, strel('disk', 18));
    filledTemp = imfill(filledTemp, 'holes');
    CC3 = bwconncomp(filledTemp);
    if CC3.NumObjects > 0
        [~, idx3] = max(cellfun(@numel, CC3.PixelIdxList));
        gloveMaskFilled = false(rows, cols);
        gloveMaskFilled(CC3.PixelIdxList{idx3}) = true;
    else
        gloveMaskFilled = filledTemp;
    end
    % Limit filled mask to within 22px of tight mask (prevents runaway expansion)
    expandedTight   = imdilate(tightMask, strel('disk', 22));
    gloveMaskFilled = gloveMaskFilled & expandedTight;
    % Apply same wrist cut as tight mask
    if ~isempty(rp)
        bb2w    = rp(1).BoundingBox;
        gTop2   = max(1,   round(bb2w(2)));
        gH2     = min(rows, round(bb2w(2) + bb2w(4))) - gTop2 + 1;
        cutRow2 = round(gTop2 + gH2 * 0.90);
        gloveMaskFilled(cutRow2:end, :) = false;
    end
end


% =========================================================================
%  DEFECT 1 — HOLES
%
%  Two complementary paths combined with OR:
%    Path A (topology): imclose → imfill → diff = enclosed voids only.
%      Finger gaps touch the image border → imfill leaves them open.
%      Real holes are fully enclosed → imfill fills them → show in diff.
%    Path B (skin): detect skin-coloured pixels inside glove region.
%      Handles cases where skin passing the HSV gate plugs the topology diff.
%
%  Blob filter: 650–50% of glove area, eccentricity < 0.97,
%               solidity > 0.45, skin fraction ≥ 22%.
% =========================================================================
function [holeMask, found] = detectHoles(img, gloveMask)
    [imgRows, imgCols] = size(gloveMask);
    hsvI = rgb2hsv(im2double(img));
    H = hsvI(:,:,1);  S = hsvI(:,:,2);  V = hsvI(:,:,3);

    % Skin tone: orange-red hue, moderate saturation, medium-to-bright value
    skinMask = ((H < 0.055) | (H > 0.93)) & ...
               (S > 0.12) & (S < 0.68)  & ...
               (V > 0.30) & (V < 0.88);

    % Look for skin pixels inside (or just outside) the glove boundary;
    % 12px dilation catches skin at the hole edge
    gloveRegion  = imdilate(gloveMask, strel('disk', 12));
    skinInGlove  = skinMask & gloveRegion;
    skinInGlove  = imopen(skinInGlove, strel('disk', 3));
    skinInGlove  = imclearborder(skinInGlove);  % remove wrist/arm skin at edges

    % Path A: remove confirmed skin so it doesn't plug the topology hole
    strictMask  = gloveMask & ~imdilate(skinInGlove, strel('disk', 4));
    closedMask  = imclose(strictMask, strel('disk', 6));
    filledMask  = imfill(closedMask, 'holes');
    topoDiff    = filledMask & ~strictMask;
    topoDiff    = imclearborder(topoDiff);

    combined = skinInGlove | topoDiff;
    combined = imopen(combined, strel('disk', 2));

    % Exclude fingertip openings (top 25%) and wrist area (bottom 20%)
    rp = regionprops(gloveMask, 'BoundingBox');
    if ~isempty(rp)
        bb       = rp(1).BoundingBox;
        topCut   = min(imgRows, round(bb(2) + bb(4) * 0.25));
        wristCut = min(imgRows, round(bb(2) + bb(4) * 0.80));
        combined(1:topCut, :)    = false;
        combined(wristCut:end, :) = false;
    end
    combined = imclearborder(combined);

    CC = bwconncomp(combined);
    holeMask = false(imgRows, imgCols);
    found    = false;
    if CC.NumObjects == 0, return; end

    gloveArea   = max(sum(gloveMask(:)), 1);
    MIN_HOLE_PX = 650;
    MAX_HOLE_PX = gloveArea * 0.50;
    st = regionprops(CC, 'Area', 'Eccentricity', 'Solidity');

    for k = 1:CC.NumObjects
        if st(k).Area < MIN_HOLE_PX || st(k).Area > MAX_HOLE_PX, continue; end
        if st(k).Eccentricity > 0.97,                            continue; end
        % Low solidity → scattered noise (knit gaps), not a real hole
        if st(k).Solidity < 0.45,                                continue; end
        % Must contain ≥ 22% skin pixels to confirm exposed skin through hole
        blobPx    = CC.PixelIdxList{k};
        skinFrac  = sum(skinMask(blobPx)) / numel(blobPx);
        if skinFrac < 0.22, continue; end
        holeMask(blobPx) = true;
        found = true;
    end
end


% =========================================================================
%  DEFECT 2 — DISCOLORATION
%
%  Analysis zone: imerode(gloveMask, disk2) minus holeMask×30px buffer.
%  Colour scoring: CIELAB a*b* deviation from 40th-percentile reference.
%    40th-percentile reference avoids median being shifted by a large stain.
%  Threshold: 3.0σ (robust σ = IQR × 1.4826).
%    3.0 (not 2.5) prevents knit-texture variation from causing false hits.
%  Blob filter: ≥ 400px, no overlap with hole buffer.
% =========================================================================
function [discoMask, found] = detectDiscoloration(img, gloveMaskFilled, holeMask, gloveMask)

    if nargin >= 4 && ~isempty(gloveMask) && any(gloveMask(:))
        baseZone = gloveMask;
    else
        baseZone = gloveMaskFilled;
    end

    % Exclude wrist band (bottom 12% of glove bbox)
    rpD = regionprops(baseZone, 'BoundingBox');
    if ~isempty(rpD)
        bbD     = rpD(1).BoundingBox;
        bandCut = round(bbD(2) + bbD(4) * 0.88);
        baseZone(bandCut:end, :) = false;
    end

    safeGlove = imerode(baseZone, strel('disk', 2));
    if ~any(safeGlove(:)), safeGlove = baseZone; end

    if nargin >= 3 && any(holeMask(:))
        holeBuffer = imdilate(holeMask, strel('disk', 30));
        safeGlove  = safeGlove & ~holeBuffer;
        if ~any(safeGlove(:)), safeGlove = baseZone & ~holeBuffer; end
        if ~any(safeGlove(:)), safeGlove = baseZone; end
    end

    labI = rgb2lab(im2double(img));
    A    = labI(:,:,2);
    B    = labI(:,:,3);
    gA   = A(safeGlove);
    gB   = B(safeGlove);

    % 40th-percentile reference — bottom 40% of sorted values = clean glove colour
    % (stains are localised so they never dominate the lower 40%)
    gA_sort = sort(gA); gB_sort = sort(gB);
    n   = numel(gA_sort);
    cut = max(1, round(n * 0.40));
    refA = median(gA_sort(1:cut));
    refB = median(gB_sort(1:cut));

    sigA = max(iqr(gA), 1.0) * 1.4826;
    sigB = max(iqr(gB), 1.0) * 1.4826;
    devA = abs(A - refA) / sigA;
    devB = abs(B - refB) / sigB;

    raw = (sqrt(devA.^2 + devB.^2) > 3.0) & safeGlove;

    % Morphology order matters: open first to kill noise, then close to bridge stain patches
    raw = imopen(raw,  strel('disk', 2));
    raw = imclose(raw, strel('disk', 8));
    raw = imopen(raw,  strel('disk', 3));

    % Build hole overlap exclusion zone (size-scaled dilation radius)
    holeOverlap = false(size(baseZone));
    if nargin >= 3 && any(holeMask(:))
        holeAreaOv = sum(holeMask(:));
        if holeAreaOv > 5000,     overlapSz = 55;
        elseif holeAreaOv > 2000, overlapSz = 40;
        else,                     overlapSz = 28;
        end
        holeOverlap = imdilate(holeMask, strel('disk', overlapSz));
    end

    CC = bwconncomp(raw);
    discoMask = false(size(baseZone));
    for k = 1:CC.NumObjects
        px = CC.PixelIdxList{k};
        if numel(px) < 400, continue; end
        if any(holeOverlap(:)) && any(holeOverlap(px)), continue; end
        discoMask(px) = true;
    end
    found = any(discoMask(:));
end


% =========================================================================
%  DEFECT 3 — DEFORMATION
%
%  Finger zone: top 30% of glove bounding box (palm excluded).
%  Column-wise: topmost glove pixel per column → height above palm baseline.
%  Gaussian smooth σ=4 preserves per-finger peak shape.
%  Group columns into "fingers" by valley threshold (35% of max height).
%  Deformation rule: finger peak > median_peak × 1.25.
%  Requires ≥ 2 valid finger groups (width ≥ 20px) for a meaningful median.
% =========================================================================
function [deformMask, found] = detectDeformation(img, gloveMask)
    deformMask = false(size(gloveMask));
    found      = false;

    rp = regionprops(gloveMask, 'BoundingBox');
    if isempty(rp), return; end

    bb           = rp(1).BoundingBox;
    rows         = size(gloveMask, 1);
    nCols        = size(gloveMask, 2);
    topRow       = max(1,    round(bb(2)));
    botRow       = min(rows, round(bb(2) + bb(4) * 0.30));
    palmBaseline = botRow;
    fingerRegion = gloveMask(topRow:botRow, :);
    colLeft      = max(1,    round(bb(1)));
    colRight     = min(nCols, round(bb(1) + bb(3)));

    tipProfile   = zeros(1, nCols);
    gloveColMask = false(1, nCols);
    actualTipRow = zeros(1, nCols);
    for c = colLeft:colRight
        idx = find(fingerRegion(:, c), 1, 'first');
        if ~isempty(idx)
            tipProfile(c)   = palmBaseline - (topRow + idx - 1);
            gloveColMask(c) = true;
            actualTipRow(c) = topRow + idx - 1;
        end
    end
    if sum(gloveColMask) < 60, return; end

    tipSmooth = imgaussflit_safe(tipProfile, 4);
    tipSmooth(~gloveColMask) = 0;
    maxH = max(tipSmooth);
    if maxH < 15, return; end

    % Group columns into finger peaks (valley = below 35% of max)
    isValley    = ~gloveColMask | (tipSmooth < maxH * 0.35);
    fingerLabel = bwlabel(~isValley);
    nFingers    = max(fingerLabel);
    if nFingers < 1, return; end

    peakH      = zeros(1, nFingers);
    groupWidth = zeros(1, nFingers);
    groupCols  = cell(1, nFingers);
    for g = 1:nFingers
        gc            = find(fingerLabel == g);
        groupCols{g}  = gc;
        groupWidth(g) = numel(gc);
        peakH(g)      = max(tipSmooth(gc));
    end

    validG = groupWidth >= 20;
    if sum(validG) < 1, return; end

    % Edge case: only one finger group visible — compare against maxH proxy
    if sum(validG) == 1
        g = find(validG, 1);
        if peakH(g) > maxH * 0.55
            gc  = groupCols{g};
            c1  = max(1, min(gc) - 8);
            c2  = min(nCols, max(gc) + 8);
            blobTopRow = max(1, topRow - 8);
            blob = false(rows, nCols);
            blob(blobTopRow:botRow, c1:c2) = gloveMask(blobTopRow:botRow, c1:c2);
            blob = imclose(blob, strel('disk', 6));
            blob = imdilate(blob, strel('disk', 10)) & gloveMask;
            deformMask = deformMask | blob;
            found = true;
        end
        return;
    end

    % Normal case: flag any finger whose peak exceeds median × 1.25
    medH = median(peakH(validG));
    thr  = medH * 1.25;

    for g = 1:nFingers
        if ~validG(g) || peakH(g) <= thr, continue; end

        gc  = groupCols{g};
        c1  = max(1,    min(gc) - 8);
        c2  = min(nCols, max(gc) + 8);

        colsInRange = gc(gc >= c1 & gc <= c2);
        if isempty(colsInRange)
            blobTopRow = max(1, topRow - 8);
        else
            tipRows = actualTipRow(colsInRange);
            tipRows = tipRows(tipRows > 0);
            if isempty(tipRows)
                blobTopRow = max(1, topRow - 8);
            else
                blobTopRow = max(1, min(tipRows) - 8);
            end
        end

        blob = false(rows, nCols);
        blob(blobTopRow:botRow, c1:c2) = gloveMask(blobTopRow:botRow, c1:c2);
        blob = imclose(blob, strel('disk', 6));
        blob = imdilate(blob, strel('disk', 10)) & gloveMask;
        deformMask = deformMask | blob;
        found = true;
    end
end


% =========================================================================
%  DRAW ELLIPSE MARKERS
%  Dilate mask (disk 50) to merge nearby blobs, then draw a bounding
%  ellipse per merged region (max 5 markers per defect type).
% =========================================================================
function drawCircles(ax, mask, clr)
    if ~any(mask(:)), return; end
    merged = imdilate(mask, strel('disk', 50));
    merged = imfill(merged, 'holes');
    CC = bwconncomp(merged);
    if CC.NumObjects == 0, return; end
    stats = regionprops(CC, 'BoundingBox', 'Area');
    lbl   = colorToLabel(clr);
    areas = [stats.Area];
    [~, ord] = sort(areas, 'descend');
    drawn = 0;
    for ki = 1:numel(ord)
        if drawn >= 5, break; end
        k = ord(ki);
        if stats(k).Area < 500, continue; end
        bb  = stats(k).BoundingBox;
        mg  = max(16, 0.12 * max(bb(3), bb(4)));
        rx  = bb(1) - mg;   ry = bb(2) - mg;
        rw  = bb(3) + 2*mg; rh = bb(4) + 2*mg;
        rectangle('Parent', ax, 'Position', [rx ry rw rh], ...
            'Curvature', [1 1], 'EdgeColor', clr, 'LineWidth', 3.0);
        text(ax, rx+rw/2, ry-6, lbl, 'Color', clr, 'FontSize', 8, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'BackgroundColor', [0 0 0], ...
            'Margin', 1, 'Interpreter', 'none');
        drawn = drawn + 1;
    end
end

function lbl = colorToLabel(clr)
    r = round(clr(1)*100); g = round(clr(2)*100); b = round(clr(3)*100);
    if     r>=95 && g<=25 && b<=25,  lbl='Hole';
    elseif r>=95 && g>=55 && b<=15,  lbl='Discoloration';
    elseif r<=15 && g>=85 && b>=85,  lbl='Deformation';
    else,                             lbl='Defect';
    end
end

function out = imgaussflit_safe(img, sigma)
    try
        out = imgaussfilt(img, sigma);
    catch
        h   = fspecial('gaussian', 2*ceil(3*sigma)+1, sigma);
        out = imfilter(img, h, 'replicate');
    end
end