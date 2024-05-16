function genData = glm_genData(tbin_size)
%
%   (NOTE: not tested yet, might have bugs.)
%   Only works for 1px for now.
%
%   Generate time-binned glm data of simulated fields, but with actual vmpv nav data.
%   Fields will be simulated at the specified bins below
%   

pv = vmpv('auto');

stc = pv.data.sessionTimeC;

% using vel filter only for now
ThresVel = 1;
conditions = ones(size(stc,1),1);
conditions = conditions & get(pv,'SpeedLimit',ThresVel);

% don't touch for now
UseMinObs = false;
if UseMinObs
    place_bins_sieved = pv.data.place_good_bins;
    view_bins_sieved = pv.data.view_good_bins;
    conditions = conditions & (pv.data.pv_good_rows);
else
    place_bins_sieved = 1:(40 * 40);
    view_bins_sieved = 1:5122;
end

% Construct new stc, with each row representing a time bin
bin_stc = nan(size(stc,1),4);
bin_stc(1,1:4) = stc(2,1:4);

current_tbin = 1; % refers to bin_stc row being filled
stc_last = 2;

dstc = diff(stc(:,1));
cstc = find(dstc ~= 0) + 1;
cstc(1:end-1,2) = cstc(2:end,1) - 1;
cstc(end,2) = size(stc,1);
cstc_track = 1;

while bin_stc(current_tbin, 1) + tbin_size <= stc(end,1)
    if ~conditions(stc_last) % do not allow any bin to include any ~condition stc rows
        bin_stc(current_tbin, 1) = stc(stc_last+1,1);
        stc_last = stc_last + 1;
        continue
    else
        while bin_stc(current_tbin, 1) < stc(stc_last+1,1)
            while ~any(cstc(cstc_track,1):cstc(cstc_track,2) == stc_last)
                cstc_track = cstc_track + 1;
            end
            match_idx = cstc(cstc_track,1):cstc(cstc_track,2); % to account for multiple simultaneously occupied bins
            match_b_idx = current_tbin:current_tbin-1+length(match_idx);
            if length(match_idx) > 1
                bin_stc(match_b_idx, 1) = bin_stc(current_tbin, 1);
                for i = 1:length(match_idx)
                    bin_stc(current_tbin+i-1, 2:4) = stc(match_idx(i), 2:4);
                end
                current_tbin = current_tbin + length(match_idx) - 1; % update index of latest filled tbin
            else
                bin_stc(current_tbin, 2:4) = stc(stc_last, 2:4);
            end
            
            bin_stc(current_tbin+1, 1) = bin_stc(current_tbin, 1) + tbin_size;
            current_tbin = current_tbin + 1;
        end
        while stc_last+1 <= size(stc,1) && stc(stc_last+1,1) <= bin_stc(current_tbin, 1)
            stc_last = stc_last + 1;
        end
    end
end

bin_stc = bin_stc(~isnan(bin_stc(:,1)),:);
bin_stc(:,5) = zeros(size(bin_stc,1),1); % 5th col contains number of spikes

% place/view bin sieving
rows_remove = [];
for k = 1:size(bin_stc,1)
    if ~any(place_bins_sieved == bin_stc(k,2)) || ~any(view_bins_sieved == bin_stc(k,4))
        rows_remove = [rows_remove k];
    end
end
bin_stc(rows_remove,:) = [];



%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Simulation
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 'place' / 'headdirection' / 'spatialview' / 'ph' / 'pv' / 'hv' / 'phv'
type = 'place';  
active_mean = 5;
background_mean = 0.5;

%%% Specify field bins here %%%
active_place = [];
active_hd = [];
active_view = [];
%%%%%%%%%%%%%%%%%%%%%%

switch type
    case 'place'
        for row = 1:size(bin_stc)
            if contains(active_place, bin_stc(row, 2))
                bin_stc(row, 5) = poissrnd(active_mean*tbin_size);
            else
                bin_stc(row, 5) = poissrnd(background_mean*tbin_size);
            end
        end
    case 'headdirection'
        for row = 1:size(bin_stc)
            if contains(active_hd, bin_stc(row, 3))
                bin_stc(row, 5) = poissrnd(active_mean*tbin_size);
            else
                bin_stc(row, 5) = poissrnd(background_mean*tbin_size);
            end
        end
    case 'spatialview'
        for row = 1:size(bin_stc)
            if contains(active_view, bin_stc(row, 4))
                bin_stc(row, 5) = poissrnd(active_mean*tbin_size);
            else
                bin_stc(row, 5) = poissrnd(background_mean*tbin_size);
            end
        end
    case 'ph'
        for row = 1:size(bin_stc)
            if contains(active_place, bin_stc(row, 2)) && contains(active_hd, bin_stc(row, 3))
                bin_stc(row, 5) = poissrnd(active_mean*tbin_size);
            elseif contains(active_place, bin_stc(row, 2)) || contains(active_hd, bin_stc(row, 3))
                bin_stc(row, 5) = poissrnd(sqrt(active_mean*tbin_size)*sqrt(background_mean*tbin_size));
            else
                bin_stc(row, 5) = poissrnd(background_mean*tbin_size);
            end
        end
    case 'pv'
        for row = 1:size(bin_stc)
            if contains(active_place, bin_stc(row, 2)) && contains(active_view, bin_stc(row, 4))
                bin_stc(row, 5) = poissrnd(active_mean*tbin_size);
            elseif contains(active_place, bin_stc(row, 2)) || contains(active_view, bin_stc(row, 4))
                bin_stc(row, 5) = poissrnd(sqrt(active_mean*tbin_size)*sqrt(background_mean*tbin_size));
            else
                bin_stc(row, 5) = poissrnd(background_mean*tbin_size);
            end
        end
    case 'hv'
        for row = 1:size(bin_stc)
            if contains(active_hd, bin_stc(row, 3)) && contains(active_view, bin_stc(row, 4))
                bin_stc(row, 5) = poissrnd(active_mean*tbin_size);
            elseif contains(active_hd, bin_stc(row, 3)) || contains(active_view, bin_stc(row, 4))
                bin_stc(row, 5) = poissrnd(sqrt(active_mean*tbin_size)*sqrt(background_mean*tbin_size));
            else
                bin_stc(row, 5) = poissrnd(background_mean*tbin_size);
            end
        end
    case 'phv'
        for row = 1:size(bin_stc)
            if contains(active_place, bin_stc(row, 2)) && contains(active_hd, bin_stc(row, 3)) && contains(active_view, bin_stc(row, 4))
                bin_stc(row, 5) = poissrnd(active_mean*tbin_size);
            elseif contains(active_place, bin_stc(row, 2)) || contains(active_hd, bin_stc(row, 3)) || contains(active_view, bin_stc(row, 4))
                bin_stc(row, 5) = poissrnd(sqrt(active_mean*tbin_size)*sqrt(background_mean*tbin_size));
            else
                bin_stc(row, 5) = poissrnd(background_mean*tbin_size);
            end
        end
    otherwise
        Error('Unrecognised type!')
end

% generate duration maps for place and view
dstc = diff([stc(1:end,1); pv.data.rplmaxtime]);
stc = stc(conditions,:);
dstc = dstc(conditions);
place_dur = zeros(1600,1);
view_dur = zeros(5122,1);
for k = 1:size(stc,1)
    place_bin = stc(k,2);
    view_bin = stc(k,4);
    if place_bin >= 1 && place_bin <= 1600  % valid place bins
        place_dur(place_bin) = place_dur(place_bin) + dstc(k);
    end
    if view_bin >= 1 && view_bin <= 5122  % valid view bins
        view_dur(view_bin) = view_dur(view_bin) + dstc(k);
    end
end

% get place and view bins that have > 0 duration
place_good_bins = find(place_dur > 0);
view_good_bins = find(view_dur > 0);


genData = struct;

genData.ThresVel = ThresVel;
genData.UseMinObs = UseMinObs;

genData.bin_stc = bin_stc;
genData.tbin_size = tbin_size;

genData.place_good_bins = place_good_bins;
genData.view_good_bins = view_good_bins;

% genData.place_dur = place_dur;
% genData.view_dur = view_dur;

genData.active_place = active_place;
genData.active_view = active_view;

save('genData.mat','genData','-v7.3');

end

