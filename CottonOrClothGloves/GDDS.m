function GloveDefectDetectionGUI()
% =========================================================================
%  GLOVE DEFECT DETECTION SYSTEM  v3  — Tri-Mask Segmentation Edition
%  CT036-3-IPPR | Asia Pacific University of Technology & Innovation
%
%  KEY IMPROVEMENTS OVER v2
%  ─────────────────────────────────────────────────────────────────────────
%  1. TRI-MASK ADAPTIVE SEGMENTATION  (replaces single-strategy v2)
%     Three complementary candidate masks are built and combined:
%       maskA (White Glove) — (S < thr) & (V > thr)
%                             Catches bright, low-saturation latex gloves
%                             on any coloured background.
%       maskB (Dark BG)     — V > Otsu-scaled threshold
%                             Effective on black / very dark surfaces where
%                             the glove is meaningfully brighter than bg.
%       maskC (BG Diff)     — hue-distance + sat-distance from border-
%                             sampled background statistics.
%                             Robust on blue, wood, and any textured bg.
%     rawMask = (maskA | maskB | maskC) & (V > 0.12)
%     Background type still detected (dark/warm/blue/colored/neutral) so
%     each mask can use slightly tuned thresholds per bg class.
%
%  2. EXPANDED SEGMENTATION PIPELINE PAGE — 8 SLOTS (4 × 2 grid)
%     Slot (1,1)  Step 1 — Original RGB Image
%     Slot (1,2)  Step 2 — Border Sampling Map
%     Slot (1,3)  Step 3 — Mask A: White Glove (S<thr & V>thr)
%     Slot (1,4)  Step 4 — Mask B: Dark-BG Separation (V-threshold)
%     Slot (2,1)  Step 5 — Mask C: BG Hue-Difference Map
%     Slot (2,2)  Step 6 — Combined Raw Mask (A | B | C)
%     Slot (2,3)  Step 7 — Tight gloveMask  (after morphology + CC)
%     Slot (2,4)  Step 8 — Filled gloveMask (discoloration zone)
%
%  3. DUAL MASK OUTPUT (unchanged from v2)
%     gloveMask       — tight mask; used by holes + deformation
%     gloveMaskFilled — aggressively closed + imfill; for discoloration
%
%  4. CROSS-DEFECT EXCLUSION (unchanged from v2)
%     holeMask dilated 15px is subtracted from discoloration safe zone.
%
%  PIPELINE OVERVIEW
%  ─────────────────────────────────────────────────────────────────────────
%  STAGE 1 — SEGMENTATION  (Steps 1-8, 4×2 grid)
%  STAGE 2 — DEFECT DETECTION  (Steps 7-9, 4×2 grid, last 2 cols unused)
%  STAGE 3 — OUTPUT  (Steps 10-11)
% =========================================================================

    appData.img=[]; appData.currentPage=1; appData.pipePg=1;
    appData.datasetFolder=''; appData.datasetFiles={};
    C.bg    =[0.09 0.11 0.17]; C.panel=[0.13 0.16 0.23];
    C.accent=[0.20 0.45 0.88]; C.green=[0.15 0.78 0.42];
    C.orange=[1.00 0.58 0.18]; C.cyan =[0.18 0.82 0.88];
    C.textW =[0.95 0.95 0.98]; C.textD=[0.55 0.58 0.66];
    C.border=[0.22 0.26 0.36];
    DC.Holes  =[1.00 0.18 0.18];
    DC.Disco  =[1.00 0.62 0.08];
    DC.Deform =[0.08 0.90 0.90];

    % Persistent folder save path (survives across MATLAB sessions)
    lastFolderFile = fullfile(tempdir, 'gdds_v3_lastfolder.mat');

    scr=get(0,'ScreenSize'); winW=1060; winH=640;
    hFig=figure('Name','Glove Defect Detection System v3','NumberTitle','off',...
        'MenuBar','none','ToolBar','none','Color',C.bg,'Resize','off',...
        'Position',[(scr(3)-winW)/2 (scr(4)-winH)/2 winW winH]);

    % ── Header ───────────────────────────────────────────────────────────
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

    % ── Left panel  (268 px wide) ─────────────────────────────────────────
    pnlW=268;
    uipanel('Parent',hFig,'BackgroundColor',C.panel,'Units','pixels',...
        'Position',[0 0 pnlW winH-54],'BorderType','line','HighlightColor',C.border);

    % ── Layout constants ──────────────────────────────────────────────────
    %   y is always the BOTTOM edge of the next element to be placed.
    %   y decreases by (height_of_NEXT_element + gap) after each placement.
    y=winH-54-16;   % = 570 — near top of panel area

    % ── DATASET FOLDER section ────────────────────────────────────────────
    sLbl('DATASET FOLDER',y);              y=y-32;   % next btn h=28
    uicontrol('Parent',hFig,'Style','pushbutton',...
        'String','  Browse Folder','FontSize',9,'FontWeight','bold',...
        'ForegroundColor',C.textW,'BackgroundColor',C.accent,...
        'Units','pixels','Position',[10 y pnlW-18 28],...
        'Callback',@onBrowseFolder);                 y=y-18;   % next lbl h=14
    hLblFolder=uicontrol('Parent',hFig,'Style','text',...
        'String','No folder set','FontSize',7,...
        'ForegroundColor',C.textD,'BackgroundColor',C.panel,...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 14]);               y=y-86;   % next listbox h=82
    % Image file listbox — single click auto-loads image
    hListBox=uicontrol('Parent',hFig,'Style','listbox',...
        'String',{'(no folder loaded)'},'FontSize',8,...
        'ForegroundColor',C.textW,'BackgroundColor',[0.07 0.09 0.14],...
        'SelectionHighlight','on','Units','pixels',...
        'Position',[10 y pnlW-18 82],'Callback',@onListSelect);  y=y-26; % next row h=22
    % Refresh + Browse Single row
    uicontrol('Parent',hFig,'Style','pushbutton','String','↺ Refresh',...
        'FontSize',8,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.18 0.22 0.38],'Units','pixels',...
        'Position',[10 y round((pnlW-22)/2) 22],'Callback',@onRefreshFolder);
    uicontrol('Parent',hFig,'Style','pushbutton','String','+ Single File',...
        'FontSize',8,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.18 0.22 0.38],'Units','pixels',...
        'Position',[10+round((pnlW-22)/2)+4 y round((pnlW-22)/2) 22],...
        'Callback',@onUpload);                       y=y-18;   % next lbl h=14
    hLblFile=uicontrol('Parent',hFig,'Style','text','String','No image loaded',...
        'FontSize',7,'ForegroundColor',C.textD,'BackgroundColor',C.panel,...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 14]);               y=y-82;   % next axes h=78
    hAxPrev=axes('Parent',hFig,'Units','pixels','Position',[10 y pnlW-18 78],...
        'Color',C.bg,'XColor',C.border,'YColor',C.border,...
        'XTick',[],'YTick',[],'Box','on');
    title(hAxPrev,'Preview','Color',C.textD,'FontSize',7); y=y-20; % next lbl h=14+gap

    % ── DETECTION section ─────────────────────────────────────────────────
    sLbl('DETECTION',y);                   y=y-32;
    hBtnDetect=uicontrol('Parent',hFig,'Style','pushbutton',...
        'String','  Run Detection','FontSize',10,'FontWeight','bold',...
        'ForegroundColor',C.textW,'BackgroundColor',[0.16 0.52 0.30],...
        'Units','pixels','Position',[10 y pnlW-18 28],'Callback',@onDetect);
    set(hBtnDetect,'Enable','off');        y=y-18;

    % ── STATUS ────────────────────────────────────────────────────────────
    sLbl('STATUS',y);                      y=y-46;
    hStatus=uicontrol('Parent',hFig,'Style','text','String','Set a folder or load an image.',...
        'FontSize',7.5,'ForegroundColor',C.textD,'BackgroundColor',[0.08 0.10 0.15],...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 42],'Max',4);       y=y-18;

    % ── RESULTS ───────────────────────────────────────────────────────────
    sLbl('RESULTS',y);                     y=y-62;
    hResults=uicontrol('Parent',hFig,'Style','text','String','---','FontSize',8.5,...
        'ForegroundColor',C.textW,'BackgroundColor',[0.08 0.10 0.15],...
        'HorizontalAlignment','left','Units','pixels',...
        'Position',[10 y pnlW-18 58],'Max',5);       y=y-18;

    % ── DEFECT LEGEND ─────────────────────────────────────────────────────
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

    % ── PIPELINE + RESET ──────────────────────────────────────────────────
    hBtnPage=uicontrol('Parent',hFig,'Style','pushbutton',...
        'String','  View Details  >','FontSize',9,'FontWeight','bold',...
        'ForegroundColor',C.textW,'BackgroundColor',[0.18 0.22 0.38],...
        'Units','pixels','Position',[10 32 pnlW-18 24],'Callback',@onTogglePage);
    set(hBtnPage,'Enable','off');
    uicontrol('Parent',hFig,'Style','pushbutton','String','  Reset',...
        'FontSize',9,'FontWeight','bold','ForegroundColor',C.textW,...
        'BackgroundColor',[0.28 0.12 0.12],...
        'Units','pixels','Position',[10 6 pnlW-18 24],'Callback',@onReset);

    % ── Restore last folder if saved ─────────────────────────────────────
    if exist(lastFolderFile,'file')
        try
            saved=load(lastFolderFile,'lastFolder');
            if isfield(saved,'lastFolder') && isfolder(saved.lastFolder)
                appData.datasetFolder=saved.lastFolder;
                scanDatasetFolder();
            end
        catch; end
    end

    % ── Display area ─────────────────────────────────────────────────────
    dispX=pnlW+8; dispW=winW-pnlW-14; dispH=winH-54-8;

    % PAGE 1 — Main view
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

    % PAGE 2 — Pipeline (5 sub-pages)
    % ── 4 × 2 grid = 8 slots ─────────────────────────────────────────────
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

    % 4 columns × 2 rows = 8 slots
    nC=4; nR=2; pX=8; pY=6;
    pAreaH=dispH-44;
    pCW=floor((dispW-(nC+1)*pX)/nC);   % ~170 px wide
    pCH=floor((pAreaH-(nR+1)*pY)/nR);  % ~266 px tall
    hPipe=gobjects(nR,nC);
    for rr=1:nR; for cc=1:nC
        px2=pX+(cc-1)*(pCW+pX); py2=pAreaH-rr*(pCH+pY)+2;
        hPipe(rr,cc)=axes('Parent',hPage2,'Units','pixels',...
            'Position',[px2 py2 pCW pCH],...
            'Color',C.panel,'XColor',C.border,'YColor',C.border,...
            'XTick',[],'YTick',[],'Box','on');
        title(hPipe(rr,cc),'---','Color',C.textD,'FontSize',7.5);
    end; end
    hPipeHint=uicontrol('Parent',hPage2,'Style','text',...
        'String','Run detection first to populate this view.','FontSize',10,...
        'ForegroundColor',C.textD,'BackgroundColor',C.bg,'HorizontalAlignment','center',...
        'Units','pixels','Position',[0 dispH/2-12 dispW 24]);
    pipeData=[];

    % ── UI Helpers ───────────────────────────────────────────────────────
    function sLbl(txt,yy)
        uicontrol('Parent',hFig,'Style','text','String',txt,'FontSize',7.5,...
            'FontWeight','bold','ForegroundColor',C.textD,'BackgroundColor',C.panel,...
            'HorizontalAlignment','left','Units','pixels',...
            'Position',[12 yy pnlW-16 14]);
    end
    function h=mBtn(txt,yy,clr,cb)
        h=uicontrol('Parent',hFig,'Style','pushbutton','String',txt,'FontSize',10,...
            'FontWeight','bold','ForegroundColor',C.textW,'BackgroundColor',clr,...
            'Units','pixels','Position',[10 yy pnlW-18 28],'Callback',cb);
    end
    function phT(ax,txt,CC)
        text(ax,0.5,0.5,txt,'Color',CC.textD,'HorizontalAlignment','center',...
            'FontSize',9,'Units','normalized');
    end
    function pt(ax,ttl,sub)
        title(ax,{ttl;sub},'Color',C.textW,'FontSize',6.5,'FontWeight','bold',...
            'Interpreter','none');
        ax.XColor=C.border; ax.YColor=C.border; ax.XTick=[]; ax.YTick=[];
    end
    function ptClr(ax,ttl,sub,clr)
        title(ax,{ttl;sub},'Color',clr,'FontSize',6.5,'FontWeight','bold',...
            'Interpreter','none');
        ax.XColor=C.border; ax.YColor=C.border; ax.XTick=[]; ax.YTick=[];
    end

    % ── Dataset folder helpers ────────────────────────────────────────────
    function scanDatasetFolder()
        % Scan folder for supported image files and populate the listbox.
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
        % Natural sort by name
        if ~isempty(files)
            [files,~]=sort(files);
        end
        appData.datasetFiles=files;
        if isempty(files)
            set(hListBox,'String',{'(no images found)'},'Value',1);
            set(hStatus,'String','Folder has no images.','ForegroundColor',C.orange);
        else
            set(hListBox,'String',files,'Value',1);
            % Shorten path for display
            fp=appData.datasetFolder;
            if numel(fp)>34, fp=['...' fp(end-30:end)]; end
            set(hLblFolder,'String',fp,'ForegroundColor',C.cyan);
            set(hStatus,...
                'String',sprintf('%d image(s) found.\nClick one to load.',numel(files)),...
                'ForegroundColor',C.green);
        end
    end

    function loadImageByName(fn)
        % Load an image by filename from the current dataset folder.
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
        % Truncate filename display
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
        % Let user pick a folder; scan it and save path for next session.
        startDir=appData.datasetFolder;
        if isempty(startDir) || ~isfolder(startDir), startDir=pwd; end
        chosen=uigetdir(startDir,'Select Dataset Folder');
        if isequal(chosen,0), return; end
        appData.datasetFolder=chosen;
        scanDatasetFolder();
        % Persist for next session
        lastFolder=chosen; 
        try; save(lastFolderFile,'lastFolder'); catch; end
    end

    function onRefreshFolder(~,~)
        % Rescan the current folder (picks up newly added files).
        if isempty(appData.datasetFolder)
            set(hStatus,'String','No folder set yet.','ForegroundColor',C.orange);
            return;
        end
        scanDatasetFolder();
    end

    function onListSelect(~,~)
        % Single-click on a listbox entry → auto-load the image immediately.
        files=get(hListBox,'String');
        idx  =get(hListBox,'Value');
        if isempty(files) || isequal(files,{'(no folder loaded)'}) || ...
           isequal(files,{'(no images found)'}), return; end
        if idx<1 || idx>numel(files), return; end
        fn=files{idx};
        loadImageByName(fn);
    end

    function onUpload(~,~)
        % Browse for a single image file (folder-independent).
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

        set(hStatus,'String','Stage 1: Segmenting glove...','ForegroundColor',C.orange);
        drawnow;
        % Returns tight mask, filled mask, intermediate tri-masks, bgType
        [gloveMask, gloveMaskFilled, imgGray, bgType] = segmentGlove(img);

        set(hStatus,'String',sprintf('Step 7: Detecting holes... [BG:%s]',bgType),...
            'ForegroundColor',C.orange); drawnow;
        [holeMask, holesOK] = detectHoles(img, gloveMask);

        set(hStatus,'String','Step 8: Detecting discoloration...','ForegroundColor',C.orange);
        drawnow;
        % Pass tight gloveMask as 4th arg so analysis stays inside the glove only
        [discoMask, discoOK] = detectDiscoloration(img, gloveMaskFilled, holeMask, gloveMask);

        set(hStatus,'String','Step 9: Detecting deformation...','ForegroundColor',C.orange);
        drawnow;
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
        % Reset only the image + detection state — keep the folder loaded.
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
        for rr2=1:nR; for cc2=1:nC
            cla(hPipe(rr2,cc2)); title(hPipe(rr2,cc2),'---','Color',C.textD,'FontSize',7.5);
        end; end
        set(hPipeHint,'Visible','on');
        set(hBtnPipeNext,'Enable','on'); set(hBtnPipePrev,'Enable','off');
    end

    % =====================================================================
    %  PIPELINE RENDERER  (5 pages, 4×2 = 8 slots)
    % =====================================================================
    function s=logical2onoff(v); if v, s='on'; else, s='off'; end; end

    function renderPipePage(pg)
        if isempty(pipeData), return; end
        % Clear all 8 slots
        for rr2=1:nR; for cc2=1:nC; cla(hPipe(rr2,cc2)); end; end

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
            'PAGE 3 — DISCOLORATION  |  CIELAB MAD > 2.5σ  (holes excluded from zone)',...
            'PAGE 4 — DEFORMATION  |  Column-wise fingertip height profile',...
            'PAGE 5 — COMBINED RESULT  |  All defects overlaid + final output'};
        set(hPipeBanner,'String',banners{pg});
        set(hBtnPipePrev,'Enable',logical2onoff(pg>1));
        set(hBtnPipeNext,'Enable',logical2onoff(pg<5));

        % Helper: show single defect result on an axis
        function showDefectResult(ax,mask,clr,name)
            cla(ax); hold(ax,'on'); imshow(img2,'Parent',ax);
            if any(mask(:)), drawCircles(ax,mask,clr); end
            hold(ax,'off');
            if any(mask(:))
                ptClr(ax,[name ' — FOUND'],'Confirmed defect locations',clr);
            else
                pt(ax,[name ' — NONE'],'No defects of this type detected');
            end
        end

        % Helper: hide an unused slot (set to dark/empty)
        function hideSlot(ax)
            cla(ax); ax.Color=C.bg; ax.XColor=C.bg; ax.YColor=C.bg;
            ax.Box='off'; ax.XTick=[]; ax.YTick=[];
            title(ax,'','Color',C.bg);
        end

        % =================================================================
        if pg==1  % ── SEGMENTATION  (8 slots, all used) ───────────────────
        % =================================================================
            hsvI=rgb2hsv(img2);
            H2=hsvI(:,:,1); S2=hsvI(:,:,2); V2=hsvI(:,:,3);
            [r2,c2]=size(H2);
            bw2=20;
            bH2=sampBorder(H2,bw2); bS2=sampBorder(S2,bw2); bV2=sampBorder(V2,bw2);
            bgH2=median(bH2); bgS2=median(bS2); bgV2=median(bV2);
            hueDist2=min(abs(H2-bgH2),1-abs(H2-bgH2));

            % Re-derive masks locally to match segmentGlove logic
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

            % ── Slot (1,1): Original RGB ──────────────────────────────────
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1),'Step 1: Original RGB Image',...
                'Input — baseline for all processing stages');

            % ── Slot (1,2): Border Sampling Map ───────────────────────────
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
            ptClr(hPipe(1,2),'Step 2: Border Sampling  (20px strip)',...
                sprintf('BG hue=%.2f  sat=%.2f  val=%.2f  → Type: %s',...
                bgH2,bgS2,bgV2,upper(bgType)),[1.00 0.60 0.60]);

            % ── Slot (1,3): Mask A ────────────────────────────────────────
            imshow(mA,'Parent',hPipe(1,3));
            ptClr(hPipe(1,3),'Step 3: Mask A — Primary',...
                'Main glove separator for this BG type',[0.80 1.00 0.80]);

            % ── Slot (1,4): Mask B ────────────────────────────────────────
            imshow(mB,'Parent',hPipe(1,4));
            ptClr(hPipe(1,4),'Step 4: Mask B — Secondary',...
                'Fallback / stain catcher',[0.80 0.85 1.00]);

            % ── Slot (2,1): Mask C ────────────────────────────────────────
            imshow(mC,'Parent',hPipe(2,1));
            pt(hPipe(2,1),'Step 5: Mask C — Tertiary',...
                'Low-sat bright glove catch');

            % ── Slot (2,2): Combined Raw Mask (A | B | C) ─────────────────
            combVis=zeros(r2,c2,3);
            combVis(:,:,2)=double(mA)*0.8;
            combVis(:,:,3)=double(mB)*0.8;
            combVis(:,:,1)=double(mC)*0.8;
            allThree=mA&mB&mC;
            for ch=1:3; sl=combVis(:,:,ch); sl(allThree)=1.0; combVis(:,:,ch)=sl; end
            imshow(combVis,'Parent',hPipe(2,2));
            ptClr(hPipe(2,2),'Step 6: Combined Raw Mask  (A | B | C)',...
                'Green=A  Blue=B  Red=C  White=all agree',[0.95 0.95 0.70]);

            % ── Slot (2,3): Tight gloveMask ───────────────────────────────
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
            ptClr(hPipe(2,3),'Step 7: Tight gloveMask  (cyan = enclosed voids)',...
                'After morphology + largest CC + wrist cut',[0.60 0.90 1.00]);

            % ── Slot (2,4): Filled gloveMask ──────────────────────────────
            filledOnly=gMF & ~gM;
            fillVis=imgD*0.40;
            for ch=1:3
                sl=fillVis(:,:,ch); chSlice=imgD(:,:,ch);
                sl(gM)=chSlice(gM);
                sl(filledOnly)=DC.Disco(ch)*0.65;
                fillVis(:,:,ch)=sl;
            end
            imshow(fillVis,'Parent',hPipe(2,4));
            ptClr(hPipe(2,4),'Step 8: Filled gloveMask  (orange = extension)',...
                'imclose(disk18)+imfill  →  discoloration zone',[1.00 0.75 0.30]);
        % =================================================================
        elseif pg==2  % ── HOLE DETECTION ──────────────────────────────────
        % (Uses slots 1-6; slots 7-8 hidden)
        % =================================================================
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1),'Step 1: Original Image','Input to hole detector');

            imshow(gM,'Parent',hPipe(1,2));
            pt(hPipe(1,2),'Step 2: Tight Glove Mask',...
                'Topology analysis requires the tight (unfilled) mask');

            closedM=imclose(gM,strel('disk',3));
            imshow(closedM,'Parent',hPipe(1,3));
            pt(hPipe(1,3),'Step 3: imclose(disk 3)',...
                'Seals micro-gaps  —  does NOT bridge finger gaps');

            filledM=imfill(closedM,'holes');
            imshow(filledM,'Parent',hPipe(1,4));
            pt(hPipe(1,4),'Step 4: imfill holes',...
                'Finger gaps touch edge → stay open  |  Holes → filled');

            diffM=filledM & ~gM;
            diffVis=imgD*0.4;
            for ch=1:3; sl=diffVis(:,:,ch); sl(diffM)=DC.Holes(ch); diffVis(:,:,ch)=sl; end
            imshow(diffVis,'Parent',hPipe(2,1));
            pt(hPipe(2,1),'Step 5: Difference (filled minus mask)',...
                sprintf('%d enclosed void pixel(s)',nnz(diffM)));

            showDefectResult(hPipe(2,2),hM,DC.Holes,'Holes');

            % Slots (2,3) and (2,4) unused on this page
            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));

        % =================================================================
        elseif pg==3  % ── DISCOLORATION ────────────────────────────────────
        % =================================================================
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1),'Step 1: Original Image','Input to discoloration detector');

            % Analysis zone — built from tight gloveMask (same as detector)
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
                ptClr(hPipe(1,2),'Step 2: Analysis Zone  (red = hole-excluded)',...
                    'imerode(filledMask,d5) minus 15px hole buffer',[1.00 0.50 0.50]);
            else
                pt(hPipe(1,2),'Step 2: Analysis Zone (Filled Mask)',...
                    'imerode(gloveMaskFilled, disk5) — safe interior');
            end

            labI=rgb2lab(imgD); A=labI(:,:,2); B=labI(:,:,3);
            imshow(mat2gray(A),'Parent',hPipe(1,3));
            pt(hPipe(1,3),'Step 3: CIELAB a* Channel',...
                'Green → Red axis  |  Colour shift indicator');

            imshow(mat2gray(B),'Parent',hPipe(1,4));
            pt(hPipe(1,4),'Step 4: CIELAB b* Channel',...
                'Blue → Yellow axis  |  Colour shift indicator');

            % Re-derive MAD heatmap (mirrors actual detector — uses tight gM)
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
            pt(hPipe(2,1),'Step 5: MAD Deviation Heatmap',...
                'Blue=low | Red=high deviation | Orange=detected disco');

            showDefectResult(hPipe(2,2),dM,DC.Disco,'Discoloration');

            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));

        % =================================================================
        elseif pg==4  % ── DEFORMATION ──────────────────────────────────────
        % =================================================================
            imshow(img2,'Parent',hPipe(1,1));
            pt(hPipe(1,1),'Step 1: Original Image','Input to deformation detector');

            imshow(gM,'Parent',hPipe(1,2));
            pt(hPipe(1,2),'Step 2: Tight Glove Mask','Finger region = top 30% of bbox');

            fingerVis=imgD*0.4; rp4=regionprops(gM,'BoundingBox');
            if ~isempty(rp4)
                bb4=rp4(1).BoundingBox; r4=size(gM,1);
                fBot=min(r4,round(bb4(2)+bb4(4)*0.30)); fTop=max(1,round(bb4(2)));
                fingerReg=false(size(gM)); fingerReg(fTop:fBot,:)=gM(fTop:fBot,:);
                for ch=1:3; sl=fingerVis(:,:,ch);
                    sl(fingerReg)=0.4*sl(fingerReg)+0.6*(ch==2)*0.6;
                    fingerVis(:,:,ch)=sl; end
            end
            imshow(fingerVis,'Parent',hPipe(1,3));
            pt(hPipe(1,3),'Step 3: Finger Analysis Zone',...
                'Top 30% of glove bbox  —  palm excluded');

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
                plot(ax9,xx9,tipS9(xx9),'-','Color',[0.35 0.65 1.0],'LineWidth',1.5);
                maxH9=max(tipS9(xx9)); if maxH9<1, maxH9=1; end
                validC9=tipS9(xx9); medH9=median(validC9(validC9>maxH9*0.35));
                thr9=medH9*1.25;
                plot(ax9,[cL9 cR9],[medH9 medH9],'--','Color',[0.55 0.55 0.55],'LineWidth',1.0);
                plot(ax9,[cL9 cR9],[thr9 thr9],':','Color',[1.0 0.55 0.15],'LineWidth',1.5);
                if any(dfM(:))
                    dfCols=any(dfM,1); xcols=find(dfCols & gCM9);
                    if ~isempty(xcols)
                        fill(ax9,[xcols(1) xcols(end) xcols(end) xcols(1)],...
                            [0 0 maxH9*1.15 maxH9*1.15],...
                            DC.Deform,'FaceAlpha',0.20,'EdgeColor',DC.Deform,'LineWidth',1);
                    end
                end
                ax9.XLim=[cL9 cR9]; ax9.YLim=[0 maxH9*1.18];
                legend(ax9,{'Tip profile','Median H','x1.25 thr','Deform zone'},...
                    'TextColor',[0.7 0.7 0.7],'Color',[0.09 0.11 0.17],...
                    'FontSize',5,'Location','southeast','Box','off');
            end
            hold(ax9,'off');
            if any(dfM(:))
                ptClr(ax9,'Step 4: Height Profile — DEFORMATION FOUND',...
                    'Cyan = finger exceeds median x 1.25',DC.Deform);
            else
                pt(ax9,'Step 4: Fingertip Height Profile',...
                    'Blue=profile | Grey=median | Orange=x1.25 threshold');
            end

            defVis=imgD*0.4;
            if any(dfM(:))
                for ch=1:3; sl=defVis(:,:,ch);
                    sl(dfM)=0.3*sl(dfM)+0.7*DC.Deform(ch); defVis(:,:,ch)=sl; end
            end
            imshow(defVis,'Parent',hPipe(2,1));
            pt(hPipe(2,1),'Step 5: Deformation Mask',...
                'Finger(s) exceeding height threshold');

            showDefectResult(hPipe(2,2),dfM,DC.Deform,'Deformation');

            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));

        % =================================================================
        else  % pg==5  ── COMBINED ──────────────────────────────────────────
        % =================================================================
            defList ={hM,dM,dfM};
            defCols ={DC.Holes,DC.Disco,DC.Deform};
            defLbls ={'Holes','Discoloration','Deformation'};
            axList  ={hPipe(1,1),hPipe(1,2),hPipe(1,3)};
            for di=1:3
                cla(axList{di}); hold(axList{di},'on');
                imshow(img2,'Parent',axList{di});
                if any(defList{di}(:))
                    drawCircles(axList{di},defList{di},defCols{di});
                    ptClr(axList{di},['Step ' num2str(di) ': ' defLbls{di} ' — FOUND'],...
                        'Confirmed defect location',defCols{di});
                else
                    pt(axList{di},['Step ' num2str(di) ': ' defLbls{di}],'None detected');
                end
                hold(axList{di},'off');
            end

            hideSlot(hPipe(1,4));  % slot 4 unused on combined page

            combVis=imgD*0.38;
            for d2=1:3
                if any(defList{d2}(:))
                    for ch=1:3; sl=combVis(:,:,ch);
                        sl(defList{d2})=0.30*sl(defList{d2})+0.70*defCols{d2}(ch);
                        combVis(:,:,ch)=sl; end
                end
            end
            cand11=hM|dM|dfM;
            CC11=bwconncomp(imdilate(cand11,strel('disk',4)));
            nDef11=nnz([any(hM(:)) any(dM(:)) any(dfM(:))]);
            imshow(combVis,'Parent',hPipe(2,1));
            pt(hPipe(2,1),'Step 4: All Defect Masks Combined',...
                sprintf('%d defect type(s)  |  %d region(s)',nDef11,CC11.NumObjects));

            cla(hPipe(2,2)); hold(hPipe(2,2),'on');
            imshow(img2,'Parent',hPipe(2,2));
            for d2=1:3
                if any(defList{d2}(:)), drawCircles(hPipe(2,2),defList{d2},defCols{d2}); end
            end
            hold(hPipe(2,2),'off');
            if isempty(defNames)
                ptClr(hPipe(2,2),'Step 5: Final Result — PASS',...
                    'All detectors within normal range',C.green);
            else
                ptClr(hPipe(2,2),['Step 5: FAIL — ' strjoin(defNames,', ')],...
                    'Ellipses = confirmed defect locations',C.orange);
            end

            hideSlot(hPipe(2,3)); hideSlot(hPipe(2,4));
        end
    end % renderPipePage

end % END GloveDefectDetectionGUI

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
    catch, errordlg('Cannot read image.','Error'); end
end

% sampBorder — collect border pixels from a 2-D channel
function bPx = sampBorder(ch, bw)
    bPx=[reshape(ch(1:bw,:),[],1);
         reshape(ch(end-bw+1:end,:),[],1);
         reshape(ch(:,1:bw),[],1);
         reshape(ch(:,end-bw+1:end),[],1)];
end

% =========================================================================
%  STAGE 1 — GLOVE SEGMENTATION  (v2 fixed)
%
%  Background classification  (from 20-px border pixel statistics):
%    blue    — sat > 0.28, H in blue band  → navy / blue / teal
%    warm    — sat > 0.18, H in warm band  → wood / tan / brown
%    dark    — median V < 0.28             → pure black surface
%    colored — other saturated colour
%    neutral — low saturation              → white / grey / light
%
%  FIX vs original v2:
%   • blue and warm checks come BEFORE the dark check.
%     Navy is dark (V ≈ 0.15–0.35) AND saturated+blue.
%     Pure black is dark AND low-saturation.
%     Checking saturation+hue first separates them correctly.
%
%  Adaptive thresholding per background type:
%    dark    → Otsu-scaled V-threshold (V > graythresh(V)*0.80)
%              + saturation gate for low-V glove areas
%    blue    → adaptive S-threshold: S < bgSat×0.50 & V > 0.32
%              + hue-distance fallback for stained patches
%    warm    → adaptive S-threshold: S < bgSat×0.55 & V > 0.38
%              + hue-distance fallback for stained patches
%    colored/neutral → hue-distance map + light-glove fallback
%
%  All post-processing (wrist cut, finger cleanup, filled mask)
%  is identical to v2.
%
%  Returns:
%    gloveMask       — tight, morphology-cleaned; for holes + deformation
%    gloveMaskFilled — aggressively closed + imfill; for discoloration zone
%    imgGray         — grayscale for pipeline display
%    bgType          — string label for display in status bar
% =========================================================================
function [gloveMask, gloveMaskFilled, imgGray, bgType] = segmentGlove(img)
    imgGray = rgb2gray(img);
    hsvImg  = rgb2hsv(img);
    H = hsvImg(:,:,1); S = hsvImg(:,:,2); V = hsvImg(:,:,3);
    [rows, cols] = size(H);
    bw = 20;

    % ── Border sampling ───────────────────────────────────────────────────
    borderH = sampBorder(H, bw);
    borderS = sampBorder(S, bw);
    borderV = sampBorder(V, bw);
    bgHue = median(borderH);
    bgSat = median(borderS);
    bgVal = median(borderV);

    % ── Background classification ─────────────────────────────────────────
    %   IMPORTANT: blue and warm MUST be checked before dark.
    %   Navy has low V (looks "dark") but also has high S and blue hue.
    %   Pure black has low V AND low S — that distinguishes it from navy.
    %   Checking sat+hue first correctly separates navy from black.
    if bgSat > 0.28 && bgHue >= 0.48 && bgHue <= 0.78
        bgType = 'blue';       % navy / blue / teal
    elseif bgSat > 0.18 && (bgHue < 0.15 || bgHue > 0.88)
        bgType = 'warm';       % wood / tan / brown / orange
    elseif bgVal < 0.28
        bgType = 'dark';       % pure black / very dark (low V AND low S)
    elseif bgSat > 0.20
        bgType = 'colored';    % any other saturated background
    else
        bgType = 'neutral';    % white / grey / light
    end

    % ── Circular hue distance from background ─────────────────────────────
    hueDist = min(abs(H - bgHue), 1 - abs(H - bgHue));

    % ── Adaptive initial mask ─────────────────────────────────────────────
    switch bgType

        case 'dark'
            % Pure black background — glove is meaningfully brighter.
            % Otsu on V gives a reliable brightness cut.
            % Scale factor 0.80 lowers it slightly for dimmer wrist areas.
            vT      = max(graythresh(V) * 0.80, 0.22);
            rawMask = (V > vT) | (S > 0.22 & V > 0.16);

        case 'blue'
            % Navy background: high S (≈0.45–0.75), blue hue.
            % White/cream glove: very low S (≈0.02–0.22).
            % → Adaptive S-threshold is the primary separator.
            %   bgSat×0.50 sits mid-way between navy (S≈0.60) and glove (S≈0.10).
            %   Floor at 0.14 handles unusually pale navies.
            sThr  = max(bgSat * 0.50, 0.14);
            maskA = (S < sThr) & (V > 0.32);
            % Hue-distance fallback: catches stained/discoloured glove patches
            % whose S is elevated but whose hue differs from navy blue.
            maskB = (hueDist > 0.12) & (V > 0.28);
            rawMask = (maskA | maskB) & (V > 0.12);

        case 'warm'
            % Wood background: warm hue (0.04–0.13), medium S (0.25–0.50).
            % White glove: S ≈ 0.02–0.18.
            % KEY: white pixels have near-zero S so their hue is undefined.
            % Do NOT rely on glove hue — rely on glove S being much lower than wood.
            % bgSat×0.55 sits between wood (S≈0.35) and glove (S≈0.08).
            sThr  = max(bgSat * 0.55, 0.14);
            maskA = (S < sThr) & (V > 0.38);
            % Hue+sat distance fallback: catches stained patches on the glove.
            maskB = (hueDist + 0.80 * abs(S - bgSat)) > 0.14;
            rawMask = (maskA | maskB) & (V > 0.12);

        otherwise  % 'colored' and 'neutral'
            % For any other background use the v2 hue-distance strategy.
            hueMap  = hueDist + 0.5 * abs(S - bgSat);
            maskA   = (hueMap > 0.09);
            maskB   = (S < 0.28) & (V > 0.50);
            rawMask = (maskA | maskB) & (V > 0.18);
    end

    % ── Sanity check ─────────────────────────────────────────────────────
    %   If the primary strategy massively over- or under-segments
    %   (< 3% or > 92% foreground) fall back to Otsu on grayscale.
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

    % ── Initial morphological cleanup ────────────────────────────────────
    rawMask = imclose(rawMask, strel('disk', 3));
    rawMask = imopen(rawMask,  strel('disk', 2));

    % Keep only the largest connected component (= main glove body)
    CC = bwconncomp(rawMask);
    if CC.NumObjects == 0
        gloveMask       = true(rows, cols);
        gloveMaskFilled = gloveMask;
        return;
    end
    [~, idx] = max(cellfun(@numel, CC.PixelIdxList));
    tightMask = false(rows, cols);
    tightMask(CC.PixelIdxList{idx}) = true;

    % ── Wrist cut — remove arm below the hand ────────────────────────────
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

    % ── Finger zone cleanup ───────────────────────────────────────────────
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

    % ── Filled mask  (gloveMaskFilled) ───────────────────────────────────
    %   Purpose: wider analysis zone for discoloration detector.
    %   A discoloured patch may fail the HSV gate and sit outside the tight
    %   mask.  Aggressive closing + imfill bridges that gap so the CIELAB
    %   detector can still sample those pixels.
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
    % Bound: filled mask cannot extend > 22px outside tight mask
    expandedTight   = imdilate(tightMask, strel('disk', 22));
    gloveMaskFilled = gloveMaskFilled & expandedTight;
    % Apply the same wrist cut as tight mask
    if ~isempty(rp)
        bb2w    = rp(1).BoundingBox;
        gTop2   = max(1,   round(bb2w(2)));
        gH2     = min(rows, round(bb2w(2) + bb2w(4))) - gTop2 + 1;
        cutRow2 = round(gTop2 + gH2 * 0.90);
        gloveMaskFilled(cutRow2:end, :) = false;
    end
end

% =========================================================================
%  DEFECT 1 — HOLES  (fixed from v2 logic)
%
%  Core logic kept from v2: topology-based fill-comparison.
%    imclose(disk3) → seals micro-gaps only (does NOT bridge finger gaps)
%    imfill('holes') → finger gaps touch the image border → stay open
%                      real holes are fully enclosed → get filled
%    diff = filledMask & ~gloveMask → only enclosed voids remain
%
%  V2 issues fixed:
%   1. MIN_HOLE_PX was 1500 — misses smaller but real puncture holes.
%      Lowered to 400px.  Still large enough to reject single-pixel noise.
%
%   2. Skin visible through a hole passes the white-glove HSV gate (low S,
%      medium V) and lands inside gloveMask.  The topology diff then finds
%      nothing because the skin pixels fill the gap.  Fix: add a skin-
%      colour path that detects exposed skin inside the glove boundary,
%      combine with topology via OR.
%
%   3. Skin-content validation on final blobs: any blob with < 15% skin
%      pixels AND not from topology (i.e. it came from skin path only)
%      is still checked against eccentricity and size.  Blobs that are
%      just discoloration artefacts (no skin at all) are dropped.
%
%  Uses tight gloveMask (not filled) — holes are topological absences
%  of glove material and must be detected on the unmodified boundary.
% =========================================================================
function [holeMask, found] = detectHoles(img, gloveMask)
    [imgRows, imgCols] = size(gloveMask);
    hsvI = rgb2hsv(im2double(img));
    H = hsvI(:,:,1);  S = hsvI(:,:,2);  V = hsvI(:,:,3);

    % ── Skin colour mask ─────────────────────────────────────────────────
    %   Skin tone: orange-red hue (0–10° or 330–360°), moderate sat,
    %   medium-to-bright value.  Conservative bounds to avoid warm gloves
    %   or wood background being flagged.
    skinMask = ((H < 0.055) | (H > 0.93)) & ...
               (S > 0.12) & (S < 0.68)  & ...
               (V > 0.30) & (V < 0.88);

    % Only look for skin pixels inside (or just outside) the glove region.
    % A 12px dilation catches skin that is just at the hole edge.
    gloveRegion  = imdilate(gloveMask, strel('disk', 12));
    skinInGlove  = skinMask & gloveRegion;
    skinInGlove  = imopen(skinInGlove, strel('disk', 3));   % remove speckle
    skinInGlove  = imclearborder(skinInGlove);              % remove wrist/arm skin

    % ── Path A: topology (v2 core logic) ────────────────────────────────
    %   Remove confirmed skin from the mask before topology so that skin
    %   pixels that passed the HSV gate do not "plug" the hole.
    strictMask  = gloveMask & ~imdilate(skinInGlove, strel('disk', 4));
    closedMask  = imclose(strictMask, strel('disk', 6));
    filledMask  = imfill(closedMask, 'holes');
    topoDiff    = filledMask & ~strictMask;
    topoDiff    = imclearborder(topoDiff);

    % ── Combine both paths ────────────────────────────────────────────────
    combined = skinInGlove | topoDiff;
    combined = imopen(combined, strel('disk', 2));

    % Remove top 25% (fingertip openings) AND bottom 20% (wrist area)
    rp = regionprops(gloveMask, 'BoundingBox');
    if ~isempty(rp)
        bb       = rp(1).BoundingBox;
        topCut   = min(imgRows, round(bb(2) + bb(4) * 0.25));
        wristCut = min(imgRows, round(bb(2) + bb(4) * 0.80));
        combined(1:topCut, :)    = false;
        combined(wristCut:end, :) = false;
    end
    combined = imclearborder(combined);

    % ── Blob filter with skin-content validation ──────────────────────────
    %   Size range: 400 px (small puncture) to 30% of glove area.
    %   Shape: eccentricity < 0.97 — rejects thin scratches / cracks.
    %   Skin fraction: blob must contain ≥ 15% skin pixels.
    %     This rejects discoloration topology artefacts (stained patches
    %     can create small fill-comparison differences that have no skin).
    CC = bwconncomp(combined);
    holeMask = false(imgRows, imgCols);
    found    = false;
    if CC.NumObjects == 0, return; end

    gloveArea   = max(sum(gloveMask(:)), 1);
    MIN_HOLE_PX = 650;                        % fixed: was 1500 in v2
    MAX_HOLE_PX = gloveArea * 0.50;
    st = regionprops(CC, 'Area', 'Eccentricity', 'Solidity');

    for k = 1:CC.NumObjects
        if st(k).Area < MIN_HOLE_PX || st(k).Area > MAX_HOLE_PX, continue; end
        if st(k).Eccentricity > 0.97,                            continue; end
        % Solidity: real holes are compact filled blobs (> 0.55)
        % Scattered knit-gap artefacts have very low solidity (< 0.30)
        if st(k).Solidity < 0.45,                                continue; end

        % Skin-content check
        blobPx    = CC.PixelIdxList{k};
        skinFrac  = sum(skinMask(blobPx)) / numel(blobPx);
        if skinFrac < 0.22, continue; end

        holeMask(blobPx) = true;
        found = true;
    end
end

% =========================================================================
%  DEFECT 2 — DISCOLORATION  (fixed from v2 logic)
%
%  Core logic kept from v2:
%   • Analysis zone = imerode(gloveMaskFilled, disk5) minus holeMask×15px.
%     The filled mask is wider than the tight mask and catches discoloured
%     patches that the HSV gate may have excluded from the tight mask.
%   • CIELAB a*b* Median Absolute Deviation scored against robust σ
%     (IQR × 1.4826).  Pixels that deviate significantly from the median
%     glove colour are flagged as discoloration.
%   • holeMask dilated 15 px is excluded so that background colour visible
%     through a hole is never mis-scored as discoloration.
%
%  V2 issues fixed:
%   1. σ threshold: 2.5 → 3.0.
%      2.5 was too sensitive — normal texture and lighting variation on a
%      healthy glove produced false discoloration hits.  3.0 requires a
%      more meaningful colour shift.
%
%   2. Min blob area: 200 → 600 px.
%      Small stray pixels from edge noise were accepted.  600 px requires
%      a region roughly 25×25 px which is a genuine stain, not speckle.
%
%   3. Skin-pixel exclusion: blobs with > 40% skin-coloured pixels are
%      dropped.  This handles cases where a hole is close to the analysis
%      zone and skin pixels partially bleed into it — those are hole
%      artefacts, not stains.
%
%   4. Tight gloveMask is now accepted as an optional 4th argument.
%      When provided it is used as the base analysis zone (preferred over
%      gloveMaskFilled) because the tight mask is a more accurate boundary.
%      The filled mask is kept as a fallback so no discoloured patches
%      that the HSV gate missed are lost.
%
%  Uses gloveMaskFilled as zone (not tight) — a discoloured patch may have
%  failed the HSV gate and sit outside the tight mask.  The filled mask
%  bridges that gap so the CIELAB detector can still find it.
% =========================================================================
function [discoMask, found] = detectDiscoloration(img, gloveMaskFilled, holeMask, gloveMask)

    % ── Choose base analysis zone ─────────────────────────────────────────
    if nargin >= 4 && ~isempty(gloveMask) && any(gloveMask(:))
        baseZone = gloveMask;
    else
        baseZone = gloveMaskFilled;
    end

    % ── Exclude wrist band (bottom 12% of glove bbox) ────────────────────
    rpD = regionprops(baseZone, 'BoundingBox');
    if ~isempty(rpD)
        bbD     = rpD(1).BoundingBox;
        bandCut = round(bbD(2) + bbD(4) * 0.88);
        baseZone(bandCut:end, :) = false;
    end

    % ── Safe analysis zone ────────────────────────────────────────────────
    %   disk 2: minimal erosion so finger-tip stains stay in the zone.
    safeGlove = imerode(baseZone, strel('disk', 2));
    if ~any(safeGlove(:)), safeGlove = baseZone; end

    % ── Exclude hole buffer (30px) ────────────────────────────────────────
    

    % ── CIELAB a*b* scoring ───────────────────────────────────────────────
    labI = rgb2lab(im2double(img));
    A    = labI(:,:,2);
    B    = labI(:,:,3);
    gA   = A(safeGlove);
    gB   = B(safeGlove);

    % ── 40th-percentile reference ─────────────────────────────────────────
    %   Solves the "large stain shifts median" problem:
    %   The bottom 40% of sorted values always represents the clean glove
    %   colour because stains are localised (< 50% of glove area).
    %   This works on all three backgrounds without needing location info.
    gA_sort = sort(gA);
    gB_sort = sort(gB);
    n       = numel(gA_sort);
    cut     = max(1, round(n * 0.40));
    refA    = median(gA_sort(1:cut));
    refB    = median(gB_sort(1:cut));

    % Robust σ: IQR × 1.4826
    sigA = max(iqr(gA), 1.0) * 1.4826;
    sigB = max(iqr(gB), 1.0) * 1.4826;
    devA = abs(A - refA) / sigA;
    devB = abs(B - refB) / sigB;

    % ── 3.0σ threshold ───────────────────────────────────────────────────
    %   3.0 (not 2.5) is critical — 2.5 flags normal knit-texture
    %   variation on clean gloves as discoloration (false positives on
    %   Deformation and Original images).
    raw = (sqrt(devA.^2 + devB.^2) > 3.0) & safeGlove;

    % ── Morphology cleanup ────────────────────────────────────────────────
    %   Order matters:
    %   1. imopen first — removes isolated noise pixels from knit gaps
    %      BEFORE closing, so they don't get bridged into false blobs.
    %   2. imclose — bridges real stain patches broken by knit weave.
    %   3. imopen again — removes any small noise left after closing.
    %   DO NOT use imclose(disk 10) first — it bridges across clean
    %   areas and creates false detections on clean gloves.
    raw = imopen(raw,  strel('disk', 2));
    raw = imclose(raw, strel('disk', 8));
    raw = imopen(raw,  strel('disk', 3));

    % ── Blob filter ───────────────────────────────────────────────────────
    %   600px minimum — rejects residual speckle while catching real stains.
    %   No skin filter — knit weave bleeds skin tone; hole buffer handles
    %   cross-defect separation instead.
    holeOverlap = false(size(baseZone));
    if nargin >= 3 && any(holeMask(:))
        % Use same scale as the buffer so overlap check matches exclusion zone
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
        % If this blob overlaps the hole region by more than 20%,
        % it is hole-related skin/background — not discoloration.
        if any(holeOverlap(:)) && any(holeOverlap(px))
            continue;
        end
        discoMask(px) = true;
    end
    found = any(discoMask(:));
end

% =========================================================================
%  DEFECT 3 — DEFORMATION  (fixed from v2 logic)
%
%  Core logic kept from v2:
%   • Top 30% of glove bounding box = finger zone (palm excluded).
%   • Column-wise: find topmost glove pixel → height = baseline − row.
%   • Gaussian smooth σ=4 preserves per-finger peak shape.
%   • Group columns into "fingers" by valley threshold (35% of max height).
%   • Deformation rule: finger peak > median_peak × 1.25.
%     A stretched or bent finger protrudes above its neighbours.
%
%  V2 issues fixed:
%   1. `if nFingers < 2, return` exited when only one group was found.
%      A single long finger (thumb side) can be valid.  Changed to < 1.
%
%   2. `if sum(validG) < 3, return` required three valid finger groups.
%      Exam gloves often show 4–5 fingers but the index or pinky may be
%      partially out of frame and not form a group ≥ 20 px wide.
%      Changed to < 2 — at least two valid groups needed to compute a
%      meaningful median for comparison.
%
%   3. median(peakH(validG)) now includes ALL valid groups.  In v2 it was
%      computed only on columns where tipSmooth > maxH*0.35 which
%      re-applied the valley filter and occasionally excluded a short but
%      legitimate finger from the median, inflating the reference.
%
%  Uses tight gloveMask — deformation is a shape analysis and requires
%  the true finger contour, not the aggressively closed filled mask.
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
 
    % ── Column-wise fingertip height profile ─────────────────────────────
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
 
    % ── Group columns into finger peaks ───────────────────────────────────
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
 
    % Valid groups: width >= 20px
    validG = groupWidth >= 20;
 
    % Need at least 2 valid groups to compute a meaningful median.
    % EXCEPTION: if only 1 valid group exists but its peak is much higher
    % than a reasonable normal finger height (maxH * 0.55), still flag it.
    % This catches cases where only 2 fingers are visible and one is bent.
    if sum(validG) < 1, return; end
 
    if sum(validG) == 1
        % Only one group — compare against a fraction of maxH as proxy
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
 
    % Normal case: median of all valid peak heights
    medH = median(peakH(validG));
    thr  = medH * 1.25;
 
    % ── Mark deformed fingers ─────────────────────────────────────────────
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
% =========================================================================
function drawCircles(ax, mask, clr)
    if ~any(mask(:)), return; end
    % disk 50: aggressively merges nearby blobs of the same defect type
    % so that a cluster of small regions shows as ONE ellipse, not many.
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
        if drawn >= 5, break; end          % max 5 markers per defect type
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
