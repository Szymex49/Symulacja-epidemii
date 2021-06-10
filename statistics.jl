size = 100
N0 = 10
meetings = 3
incubation_time = 5
immunity_time = 240
lockdowns = []
vaccination_day = 400
vaccinations = 0.004
vaccine_immunity_time = 180
death_prop = 0.002
recovery_prop = 0.04
infection_propability = 0.8
symptoms_prop = 0.5
move_propability = 0.002
T = 300
display_heatmap = false
display_plot = false


counter = 1
meetings = []
deaths = []
max_infected = []

# Run three simulations for each moving propability in range from 0.01 to 0.001
for meetings_number in 4:-1:1
    deaths_results = []
    max_infected_results = []
    
    # Run three simulations and calculate the average values
    for simulation in 1:3
        result = area_epidemic_simulation(size, N0, meetings, incubation_time, immunity_time, lockdowns,
                vaccination_day, vaccinations, vaccine_immunity_time,
                death_prop, recovery_prop, infection_propability, symptoms_prop, move_prop, T,
                display_heatmap, display_plot)
        
        append!(deaths_results, result[1])
        append!(max_infected_results, result[2])
        
        print(" $counter > ")   # Progress bar
        counter += 1
    end
    
    average_deaths = deaths_results |> mean |> floor |> Int
    average_max_infected = max_infected_results |> mean |> floor |> Int
    
    append!(meetings, meetings_number)
    append!(deaths, average_deaths)
    append!(max_infected, average_max_infected)
end

data = DataFrame(meetings=meetings,
                deaths=deaths,
                max_infected=max_infected) |> display
