function [kspace, bruker] = read_bruker(jobPath)
% READBRUKERKSPACE 读取单个 Bruker Paravision job 的 k-space 原始数据
%
% 输入：
%   jobPath — 包含 rawdata.job0 的 job 文件夹路径
%
% 输出：
%   kspace  — 复数矩阵 [Nx, Ny, Nz, Nch]
%   bruker  — 结构体，包含 acqp 与 method 参数

    %% --- 1. 读取头文件 ---
    acqpPath   = fullfile(jobPath, 'acqp');
    methodPath = fullfile(jobPath, 'method');
    bruker.acqp   = readBrukerHeader(acqpPath);
    bruker.method = readBrukerHeader(methodPath);

    %% --- 2. 提取关键信息 ---
    Nx   = bruker.method.PVM_EncMatrix(1);   % readout 点数
    Ny   = bruker.method.PVM_EncMatrix(2);   % phase 编码点数
    Nz   = bruker.acqp.NSLICES;              % 切片数
    Nch  = bruker.method.PVM_EncNReceivers;  % 通道数
    rare = bruker.method.PVM_RareFactor;     % RARE 因子

    fprintf('读取 %s\n', fullfile(jobPath, 'rawdata.job0'));
    fprintf('Nx=%d, Ny=%d, Nz=%d, Nch=%d, RARE=%d\n', Nx, Ny, Nz, Nch, rare);

    %% --- 3. 读取原始数据 ---
    fid = fopen(fullfile(jobPath, 'rawdata.job0'), 'r', 'ieee-le');
    if fid == -1
        error('无法打开文件：%s', fullfile(jobPath, 'rawdata.job0'));
    end
    raw = fread(fid, 'int32');
    fclose(fid);

    % 转换为复数
    if mod(numel(raw), 2) ~= 0
        raw = raw(1:end-1);
    end
    raw_complex = complex(double(raw(1:2:end)), double(raw(2:2:end)));

    %% --- 4. reshape 成 k-space ---
    expected_size = Nx * Nch * rare * Nz * (Ny / rare);
    if numel(raw_complex) < expected_size
        warning('数据点数少于预期：%d < %d', numel(raw_complex), expected_size);
    end

    kspace = reshape(raw_complex(1:expected_size), [Nx, Nch, rare, Nz, Ny/rare]);
    kspace = permute(kspace, [1, 5, 3, 4, 2]);  % [Nx, Ny, RARE, Nz, Nch]
    kspace = reshape(kspace, [Nx, Ny, Nz, Nch]); % 合并 RARE → Ny

    %% --- 5. 应用切片顺序 ---
    sliceOrder = bruker.method.PVM_ObjOrderList(:);
    sliceOrder = sliceOrder + 1;
    [~, invOrder] = sort(sliceOrder);

    if numel(sliceOrder) == Nz
        kspace = kspace(:, :, invOrder, :);
    else
        warning('PVM_ObjOrderList 长度(%d) 与 Nz(%d) 不符，跳过排序。', ...
                numel(sliceOrder), Nz);
    end

    %% --- 6. 可视化检查 ---
    midZ = round(Nz / 2);
    figure;
    imagesc(abs(squeeze(kspace(:,:,midZ,1))));
    axis image; colormap(jet); colorbar;
    title(sprintf('k-space 幅度图（中央切片 %d，通道 1）', midZ));

    fprintf('读取完成。');
end