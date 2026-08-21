function stats = fooof_compare_panels(dataN, dataA, ylabels, opt)
% FOOOF_COMPARE_PANELS  Generic two-group comparison figure, one panel per
% parameter (jittered subjects + mean/SEM + t-test/Mann-Whitney/Cohen's d).
%
% dataN, dataA : 1 x P cell arrays of value vectors (NT, ASD). NaNs are dropped.
% ylabels      : 1 x P cellstr, the y-axis label (with units) per panel.
% opt fields   : name1, name2 (group names); col1, col2 (RGB); titleStr;
%                subtitleStr (e.g. channels included).
%
% Returns a struct array of stats (one per parameter). Low-level engine used by
% plot_fooof_periodic and plot_fooof_aperiodic.

P = numel(dataN);
n1 = getf(opt,'name1','Group 1'); n2 = getf(opt,'name2','Group 2');
c1 = getf(opt,'col1',[0.15 0.60 0.20]); c2 = getf(opt,'col2',[0.00 0.45 0.74]);

figure('Color','w','Position',[60 90 max(360*P,720) 450]);
stats = struct([]);
for i = 1:P
    x1 = dataN{i}(:); x1 = x1(isfinite(x1));
    x2 = dataA{i}(:); x2 = x2(isfinite(x2));
    s.label = ylabels{i}; s.n1=numel(x1); s.n2=numel(x2);
    s.m1=mean(x1); s.m2=mean(x2); s.sd1=std(x1); s.sd2=std(x2);
    [s.t,s.df,s.p_t] = ttest2_local(x1,x2);
    s.p_mw = ranksum_safe(x1,x2);
    sp = sqrt(((s.n1-1)*s.sd1^2+(s.n2-1)*s.sd2^2)/max(s.n1+s.n2-2,1));
    s.cohen_d = (s.m1-s.m2)/sp;
    if i==1, stats=s; else, stats(i)=s; end %#ok<AGROW>

    subplot(1,P,i); hold on;
    jitter(1,x1,c1); jitter(2,x2,c2); errbar(1,x1,c1); errbar(2,x2,c2);
    set(gca,'XTick',[1 2],'XTickLabel',{n1,n2},'FontSize',10);
    xlim([0.4 2.6]); ylabel(ylabels{i}); grid on; box on;
    yl=ylim; ytop=yl(2)+0.10*diff(yl);
    plot([1 2],[ytop ytop],'k-','LineWidth',1);
    text(1.5,ytop,sprintf('%s p=%.3f', star(s.p_t), s.p_t), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9);
    ylim([yl(1), ytop+0.12*diff(yl)]);
    title(sprintf('d = %.2f', s.cohen_d),'FontSize',10);
end

ttl = getf(opt,'titleStr','');
sub = getf(opt,'subtitleStr','');
if isempty(sub)
    sgtitle(ttl,'FontWeight','bold','Interpreter','tex');
else
    sgtitle({ttl, ['\rm\fontsize{9}\color[rgb]{0.35,0.35,0.35}' sub]}, ...
        'FontWeight','bold','Interpreter','tex');
end
end

% ----------------------------- helpers -----------------------------------
function v = getf(s,f,d), if isfield(s,f)&&~isempty(s.(f)), v=s.(f); else, v=d; end; end
function jitter(xc,y,col)
xj = xc + (rand(numel(y),1)-0.5)*0.18;
scatter(xj,y,42,col,'filled','MarkerFaceAlpha',0.55,'HandleVisibility','off');
end
function errbar(xc,y,col)
m=mean(y); e=std(y)/sqrt(max(numel(y),1));
plot([xc-0.22 xc+0.22],[m m],'-','Color',col*0.7,'LineWidth',3);
plot([xc xc],[m-e m+e],'-','Color',col*0.7,'LineWidth',1.5);
end
function s=star(p)
if p<0.001, s='***'; elseif p<0.01, s='**'; elseif p<0.05, s='*'; else, s='n.s.'; end
end
function [t,df,p]=ttest2_local(x,y)
x=x(:);y=y(:);nx=numel(x);ny=numel(y);
if nx<2||ny<2, t=NaN;df=NaN;p=NaN; return; end
vx=var(x);vy=var(y);
t=(mean(x)-mean(y))/sqrt(vx/nx+vy/ny);
df=(vx/nx+vy/ny)^2/((vx/nx)^2/(nx-1)+(vy/ny)^2/(ny-1));
if exist('tcdf','file'), p=2*(1-tcdf(abs(t),df)); else, p=NaN; end
end
function p=ranksum_safe(x,y)
if exist('ranksum','file')&&~isempty(x)&&~isempty(y)
    try, p=ranksum(x,y); catch, p=NaN; end
else, p=NaN; end
end
