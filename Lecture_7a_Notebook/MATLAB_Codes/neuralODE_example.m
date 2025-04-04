%% Generate and visualize the data
x0 = [2; 0];
A = [-0.1 -1; 1 -0.1];
trueModel = @(t,y) A*y;

numTimeSteps = 2000;
T = 15;
odeOptions = odeset(RelTol=1.e-7);
t = linspace(0, T, numTimeSteps);
[~, xTrain] = ode45(trueModel, t, x0, odeOptions);
xTrain = xTrain';

figure
plot(xTrain(1,:),xTrain(2,:))
title("Ground Truth Dynamics") 
xlabel("x(1)") 
ylabel("x(2)")
grid on

%% Parse data and preprocessing
neuralOdeTimesteps = 40;
dt = t(2);
timesteps = (0:neuralOdeTimesteps)*dt;
neuralOdeParameters = struct;
stateSize = size(xTrain,1);
hiddenSize = 20;

neuralOdeParameters.fc1 = struct;
sz = [hiddenSize stateSize];
neuralOdeParameters.fc1.Weights = initializeGlorot(sz, hiddenSize, stateSize);
neuralOdeParameters.fc1.Bias = initializeZeros([hiddenSize 1]);

neuralOdeParameters.fc2 = struct;
sz = [stateSize hiddenSize];
neuralOdeParameters.fc2.Weights = initializeGlorot(sz, stateSize, hiddenSize);
neuralOdeParameters.fc2.Bias = initializeZeros([stateSize 1]);

%% Specify Training Parametrs
gradDecay = 0.9;
sqGradDecay = 0.999;
learnRate = 0.002;
numIter = 1200;
miniBatchSize = 200;
plotFrequency = 50;
averageGrad = [];
averageSqGrad = [];
monitor = trainingProgressMonitor(Metrics="Loss", ...
    Info=["Iteration","LearnRate"],XLabel="Iteration");
numTrainingTimesteps = numTimeSteps;
trainingTimesteps = 1:numTrainingTimesteps;
plottingTimesteps = 2:numTimeSteps;
iteration = 0;
while iteration < numIter && ~monitor.Stop
    iteration = iteration + 1;
    [X, targets] = createMiniBatch(numTrainingTimesteps, neuralOdeTimesteps, miniBatchSize, xTrain);
    % Evaluate network and compute loss and gradients
    [loss,gradients] = dlfeval(@modelLoss,timesteps,X,neuralOdeParameters,targets);
    % Update network
    [neuralOdeParameters,averageGrad,averageSqGrad] = adamupdate(neuralOdeParameters,gradients,averageGrad,averageSqGrad,iteration,...
        learnRate,gradDecay,sqGradDecay);
    recordMetrics(monitor,iteration,Loss=loss);
    % Plot predicted vs. real dynamics
    if mod(iteration,plotFrequency) == 0  || iteration == 1
        % Use ode45 to compute the solution 
        y = dlode45(@odeModel,t,dlarray(x0),neuralOdeParameters,DataFormat="CB");
        plot(xTrain(1,plottingTimesteps),xTrain(2,plottingTimesteps),"r--")
        hold on
        plot(y(1,:),y(2,:),"b-")
        hold off
        xlabel("x(1)")
        ylabel("x(2)")
        title("Predicted vs. Real Dynamics")
        legend("Training Ground Truth", "Predicted")
        drawnow
    end
    updateInfo(monitor,Iteration=iteration,LearnRate=learnRate);
    monitor.Progress = 100*iteration/numIter;
end


function X = model(tspan,X0,neuralOdeParameters)

X = dlode45(@odeModel,tspan,X0,neuralOdeParameters,DataFormat="CB");

end

function y = odeModel(~,y,theta)

y = tanh(theta.fc1.Weights*y + theta.fc1.Bias);
y = theta.fc2.Weights*y + theta.fc2.Bias;

end

function [loss,gradients] = modelLoss(tspan,X0,neuralOdeParameters,targets)

% Compute predictions.
X = model(tspan,X0,neuralOdeParameters);

% Compute L1 loss.
loss = l1loss(X,targets,NormalizationFactor="all-elements",DataFormat="CBT");

% Compute gradients.
gradients = dlgradient(loss,neuralOdeParameters);

end


function [x0, targets] = createMiniBatch(numTimesteps,numTimesPerObs,miniBatchSize,X)

% Create batches of trajectories.
s = randperm(numTimesteps - numTimesPerObs, miniBatchSize);

x0 = dlarray(X(:, s));
targets = zeros([size(X,1) miniBatchSize numTimesPerObs]);

for i = 1:miniBatchSize
    targets(:, i, 1:numTimesPerObs) = X(:, s(i) + 1:(s(i) + numTimesPerObs));
end

end


function plotTrueAndPredictedSolutions(xTrue,xPred)

xPred = squeeze(xPred)';

err = mean(abs(xTrue(2:end,:) - xPred), "all");

plot(xTrue(:,1),xTrue(:,2),"r--",xPred(:,1),xPred(:,2),"b-",LineWidth=1)

title("Absolute Error = " + num2str(err,"%.4f"))
xlabel("x(1)")
ylabel("x(2)")

xlim([-2 3])
ylim([-2 3])

legend("Ground Truth","Predicted")

end