%=========================================================================%
% Data Preparation for Dynare
% Carlstrom and Fuerst Model (1997, AER)
% Modified: Feb 2025
%=========================================================================%
% Email: Nea22@sfu.ca

clear; clc;

% === Add API key here ===
api_key = '00f67200d4a7ae0b3a2a4f90a8b0c343';

% === Define Start and End Dates ===
start_year = 1980;
end_year = 2019;
num_obs = (end_year - start_year + 1) * 4; % 160 quarterly observations

% === Function to Fetch Data from FRED ===
fetch_fred = @(series_id) webread(['https://api.stlouisfed.org/fred/series/observations?series_id=', series_id, '&api_key=', api_key, '&file_type=json&observation_start=1980-01-01&observation_end=2019-12-31']);

% === Download Data from FRED ===
try
    % 1. **Output (Real GDP)**
    Y_data = fetch_fred('GDPC1');
    Y = str2double({Y_data.observations.value})';

    % 2. **Risk-Free Interest Rate (Federal Funds Rate)**
    r_data = fetch_fred('FEDFUNDS');
    r_monthly = str2double({r_data.observations.value})' / 100;
    r = r_monthly(3:3:end); % Convert to quarterly

    % 3. **Investment**
    I_data = fetch_fred('GPDIC1');
    I = str2double({I_data.observations.value})';

    % 4. **Corporate Bond Spread (Baa - Aaa)**
    Baa_data = fetch_fred('BAA');
    Aaa_data = fetch_fred('AAA');
    Baa = str2double({Baa_data.observations.value})';
    Aaa = str2double({Aaa_data.observations.value})';
    rpBANK = mean(reshape(Baa(1:480), 3, []))' - mean(reshape(Aaa(1:480), 3, []))';

    % 5. **Labor Hours**
    H_data = fetch_fred('HOANBS');
    H = str2double({H_data.observations.value})';

    % 6. **Consumption**
    nominal_C_data = fetch_fred('PCEC');  
    GDP_deflator_data = fetch_fred('GDPDEF');
    C = (str2double({nominal_C_data.observations.value})' ./ str2double({GDP_deflator_data.observations.value})') * 100;

    % 7. **Capital Stock**
    K_data = fetch_fred('RKNANPUSA666NRUG');
    K = repelem(str2double({K_data.observations.value})', 4) / 1000;
    K = K(1:num_obs);

    % 8. **Net Worth (Entrepreneurial Wealth)**
    n_data = fetch_fred('TNWMVBSNNCB');
    n = str2double({n_data.observations.value})';

    % 9. **Debt (Credit Market Debt)**
    lev_data = fetch_fred('TCMDO');
    lev = str2double({lev_data.observations.value})';

    % 10. **Stock Market Value (Equity)**
    equity_data = fetch_fred('NASDAQCOM');
    equity = str2double({equity_data.observations.value})';

    % === Ensure All Variables Have 160 Observations ===
    all_vars = {Y, r, I, rpBANK, H, C, K, lev, n, equity};

    for i = 1:length(all_vars)
        if length(all_vars{i}) < num_obs
            missing_quarters = num_obs - length(all_vars{i});
            all_vars{i} = [repmat(all_vars{i}(1), missing_quarters, 1); all_vars{i}];
        elseif length(all_vars{i}) > num_obs
            all_vars{i} = all_vars{i}(1:num_obs);
        end
    end

    [Y, r, I, rpBANK, H, C, K, lev, n, equity] = all_vars{:};

    % Compute q, LA, A, and mu
    q = (equity + lev) ./ K;
    LA = Y ./ H;
    alpha = 0.29868; 
    zeta = 1 - alpha - 0.0001;
    A = Y ./ (K.^alpha .* H.^zeta .* n.^(1 - alpha - zeta));
    mu = (rpBANK - mean(rpBANK)) / std(rpBANK);

    % === Fix NaN values in equity and q ===
    if isnan(equity(1))
        first_valid_equity = find(~isnan(equity), 1, 'first');
        if ~isempty(first_valid_equity)
            equity(1) = equity(first_valid_equity);
        end
    end

    if isnan(q(1))
        first_valid_q = find(~isnan(q), 1, 'first');
        if ~isempty(first_valid_q)
            q(1) = q(first_valid_q);
        end
    end

catch ME
    disp('Error fetching data from FRED:');
    disp(ME.message);
end

% === Ensure All Computed Variables Have 160 Observations ===
[q, LA, A, mu] = deal(fillmissing(q, 'previous'), ...
                      fillmissing(LA, 'previous'), ...
                      fillmissing(A, 'previous'), ...
                      fillmissing(mu, 'previous'));

% === Debugging Output (Check Sizes) ===
disp(['Size of Y: ', num2str(length(Y))]);
disp(['Size of r: ', num2str(length(r))]);
disp(['Size of I: ', num2str(length(I))]);
disp(['Size of rpBANK: ', num2str(length(rpBANK))]);
disp(['Size of H: ', num2str(length(H))]);
disp(['Size of C: ', num2str(length(C))]);
disp(['Size of K: ', num2str(length(K))]);
disp(['Size of lev: ', num2str(length(lev))]);
disp(['Size of n: ', num2str(length(n))]);
disp(['Size of equity: ', num2str(length(equity))]);
disp(['Size of q: ', num2str(length(q))]);
disp(['Size of LA: ', num2str(length(LA))]);
disp(['Size of A: ', num2str(length(A))]);
disp(['Size of mu: ', num2str(length(mu))]);

% === Create Table with Correct Column Names ===
macro_data = table(Y, r, I, rpBANK, H, C, K, lev, n, equity, q, LA, A, mu, ...
                   'VariableNames', {'Y', 'r', 'I', 'rpBANK', 'H', 'C', 'K', ...
                                    'lev', 'n', 'Equity', 'q', 'LA', 'A', 'mu'});

% === Save Data ===
writetable(macro_data, 'macro_data.csv');
save macro_data.mat macro_data;

disp('✅ Data preparation complete!');

data = readtable('macro_data.csv');  % Load your dataset
data.log_Y = fillmissing([NaN; diff(log(data.Y))], 'previous');
data.log_C = fillmissing([NaN; diff(log(data.C))], 'previous');
data.log_I = fillmissing([NaN; diff(log(data.I))], 'previous'); 
data.log_r = fillmissing([NaN; diff(log(data.r))], 'previous');
data.log_q = fillmissing([NaN; diff(log(data.q))], 'previous');
data.log_LA = fillmissing([NaN; diff(log(data.LA))], 'previous');
data.log_A = fillmissing([NaN; diff(log(data.A))], 'previous');
data.log_H = fillmissing([NaN; diff(log(data.H))], 'previous');
data.log_rpBANK = fillmissing([NaN; diff(log(data.rpBANK))], 'previous');


writetable(data, 'macro_data_log.csv');  % Save it back
