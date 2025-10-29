clc;clear;
% 读取原始数据kspace
baseDir = 'E:\bruker\20250928_094924_20250928st_1_1_1'; % 输入文件路径
jobFolders = dir(fullfile(baseDir, '*'));
jobFolders = jobFolders([jobFolders.isdir]);
jobFolders = jobFolders(~ismember({jobFolders.name}, {'.', '..', 'AdjProtocols', 'AdjResult'}));

n = 6; % 输入第几个文件
job = fullfile(baseDir, jobFolders(n).name);
[kspace, bruker] = read_bruker(job);

%% 
% 平移12格到中心
kspace_centered = circshift(kspace, [0, 12, 0, 0]);
figure; imagesc(squeeze(abs(kspace_centered(:,:,20,1))))
axis image; 
colormap(jet);
colorbar;
%% 
% 转换到图像域显示
img_space = zeros(size(kspace_centered), 'like', kspace_centered);
for ch = 1:size(kspace_centered, 4)
    for z = 1:size(kspace_centered, 3)
        img_space(:,:,z,ch) = fftshift(ifft2(ifftshift(kspace_centered(:,:,z,ch))));
    end
end
figure;
imagesc(abs(img_space(:,:,20,1)));
axis image; colormap(gray); colorbar;
