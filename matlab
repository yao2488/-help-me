% 读取Excel数据（需修改文件路径）
[data, ~, raw] = xlsread('c:\Users\lenovo\OneDrive\桌面\雪旱数据\M\插值结果 - 副本.xlsx');
station_id = data(:,1);        % A列：区站号
year = data(:,7);              % G列：年
month = data(:,8);             % H列：月
elements = data(:,10:23);      % J-W列：气象要素（共14个要素）

% 预处理数据
years = unique(year);
num_years = length(years);
elements_labels = raw(1,10:23);

% 标题
elements_labels = regexprep(elements_labels, '(\w+)_avg', '\\overline{$1}');  
elements_labels = regexprep(elements_labels, '(\w+)_(max|min|cum)', '$1_{\\mathrm{$2}}');  

% 单位
elements_labels = strrep(elements_labels, '[℃]', '~[^{\circ}\mathrm{C}]');
elements_labels = strrep(elements_labels, '[mm]', '~[\mathrm{mm}]');
elements_labels = strrep(elements_labels, '[hPa]', '~[\mathrm{hPa}]');
elements_labels = strrep(elements_labels, '[m/s]', '~[\mathrm{m/s}]');
elements_labels = strrep(elements_labels, '[%]', '~[\mathrm{\%}]');
elements_labels = strrep(elements_labels, '[h]', '~[\mathrm{h}]');
elements_labels = strrep(elements_labels, '[m]', '~[\mathrm{m}]');

% 添加LaTeX
elements_labels = cellfun(@(x) ['$' x '$'], elements_labels, 'UniformOutput', false);

% 按月份聚合所有年份数据
all_years_mask = true(size(year));  % 包含所有年份
month_groups = findgroups(month(all_years_mask));

% 计算各月整体平均值和标准差（跨年份）
monthly_avg = splitapply(@(x) mean(x,1,'omitnan'), elements(all_years_mask,:), month_groups);
monthly_std = splitapply(@(x) std(x,0,1,'omitnan'), elements(all_years_mask,:), month_groups);

% 绘图设置
elem_names = elements_labels;
num_elements = length(elem_names);

% 增大图形尺寸，减少边距
figure('Units','normalized','Position',[0.06 0.06 0.85 0.85], 'Color','w',...
    'DefaultTextInterpreter','latex');
t = tiledlayout(7,2,'TileSpacing','compact','Padding','compact');

for elem_idx = 1:num_elements
    nexttile;
    
    % 删除所有尺寸调整代码，恢复默认布局
    % 提取跨年份数据
    elem_avg = monthly_avg(:,elem_idx);
    elem_std = monthly_std(:,elem_idx);
    x = 1:12;
    
    % 绘制标准差区域（深紫色）
    valid_idx = ~isnan(elem_avg) & ~isnan(elem_std);
    fill_x = x(valid_idx);
    fill_upper = elem_avg(valid_idx) + elem_std(valid_idx);
    fill_lower = elem_avg(valid_idx) - elem_std(valid_idx);
    
    fill([fill_x fliplr(fill_x)], [fill_lower; flipud(fill_upper)],...
        [108/256 97/256 215/256], 'FaceAlpha',0.1, 'EdgeColor','none');
    hold on;
    
    % 绘制平均值曲线（黑色）
    plot(x, elem_avg, 'k-', 'LineWidth', 2);
    
    % 计算数据范围（考虑标准差区域）
    data_min = min(fill_lower);
    data_max = max(fill_upper);
    
    % 特殊处理常数数据
    if data_min == data_max
        if data_min == 0
            data_min = -1;
            data_max = 1;
        else
            data_min = data_min - 1;
            data_max = data_max + 1;
        end
    end
    
    % 计算1-2-5步长
    data_range = data_max - data_min;
    exponent = floor(log10(data_range));
    if isinf(exponent) || isnan(exponent)
        exponent = 0;
    end
    base_step = 10^exponent;
    normalized_range = data_range / base_step;
    
    % 选择最优步长（1,2,5的倍数）
    if normalized_range <= 2
        step_size = 0.5 * base_step;
    elseif normalized_range <= 5
        step_size = base_step;
    elseif normalized_range <= 10
        step_size = 2 * base_step;
    else
        step_size = 5 * base_step;
    end
    
    % 确保步长为整数且至少为1
    if step_size < 1
        step_size = max(1, round(step_size));
    else
        step_size = round(step_size);
    end
    
    % 计算坐标轴范围（确保边界有刻度）
    min_tick = floor(data_min / step_size) * step_size;
    max_tick = ceil(data_max / step_size) * step_size;
    
    % 设置坐标轴范围
    ylim([min_tick, max_tick]);
    
    % 生成刻度位置
    y_ticks = min_tick:step_size:max_tick;
    
    % 设置刻度和标签（移除全局加粗）
    set(gca, 'YTick', y_ticks, 'YTickLabel', arrayfun(@(x) num2str(x), y_ticks, 'UniformOutput', false),...
        'FontSize', 14);  % 移除了FontWeight参数

    ylh = ylabel(elem_names{elem_idx}, 'Interpreter', 'latex', 'FontSize', 16,...
        'FontWeight', 'bold', 'Rotation', 90, 'VerticalAlignment','middle',...
        'HorizontalAlignment','center');
    % 统一标签垂直位置（使用数据范围中点）
    y_range = ylim;
    ylh.Position(2) = (y_range(2) + y_range(1)) / 2;  % 替代mean(ylim)
    % 统一水平位置
    ylh.Position(1) = 0.3;  % 从-0.5调整为-0.3（继续向右移动）

    % 设置坐标轴属性（移除了全局字体加粗）
    set(gca, 'Layer', 'top', 'TickLabelInterpreter', 'latex',...
        'LineWidth', 1.5);  % 仅保留线宽设置
    xlim([1 12]);
end
