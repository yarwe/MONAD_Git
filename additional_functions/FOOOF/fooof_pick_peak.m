function [cf, pw, bw, present] = fooof_pick_peak(pk, band)
% FOOOF_PICK_PEAK  Highest-power peak whose center frequency is inside a band.
%
% pk    - nPk x 3 peak_params [CF PW BW]
% band  - [lo hi] frequency window (Hz)
% Returns the [CF PW BW] of the max-power peak in the band, or NaNs + present=false.
cf = NaN; pw = NaN; bw = NaN; present = false;
if isempty(pk), return; end
in = pk(:,1) >= band(1) & pk(:,1) <= band(2);
if ~any(in), return; end
c = pk(in,:); [~,k] = max(c(:,2));
cf = c(k,1); pw = c(k,2); bw = c(k,3); present = true;
end
