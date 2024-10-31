function poisson_pde_fem
    model = createpde();
    geometryFromEdges(model,@lshapeg);
    pdegplot(model,"EdgeLabels","on")
    ylim([-1.1,1.1])
    axis equal
    % Plot the solution
    applyBoundaryCondition(model,"dirichlet", ...
                             "Edge",1:model.Geometry.NumEdges, ...
                             "u",0);
    specifyCoefficients(model,"m",0,...
                          "d",0,...
                          "c",1,...
                          "a",0,...
                          "f",1);
    generateMesh(model,"Hmax",0.25);
    results = solvepde(model);
    pdeplot(model,"XYData",results.NodalSolution)

end

