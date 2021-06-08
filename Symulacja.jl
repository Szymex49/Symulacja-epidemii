using Plots: append!
using Plots

function area_epidemic_simulation(size, N0, meetings, incubation_time, immunity_time, lockdowns,
    vaccination_day, vaccinations, vaccine_immunity_time, death_prop, recovery_prop, infection_propability, symptoms_prop, T,
    display_heatmap=true, display_plot=true)
    # 0 - dead
    # 1 - susceptible
    # 2 - exposed
    # 3 - infected
    # 4 - recovered

    dead = []
    susceptible = collect(1:size^2)
    exposed = []
    infected = []
    infected_asymptomatic = []
    recovered = []
    vaccinated = []
    unvaccinated = collect(1:size^2)

    total_infected_record = [N0]
    infected_record = [0]
    dead_record = [0]

    population = ones(size, size)
    infection_days = fill(T, size, size)
    recovery_days = fill(T, size, size)
    vaccination_days = fill(T, size, size)
    vaccinations = floor(vaccinations * size^2)

    # Random first infected
    for person in 1:N0
        index = rand(susceptible)
        population[index] = 3
        append!(infected_asymptomatic, index)
        filter!(i -> i != index, susceptible)
    end

    # For each day in T days
    anim = @animate for t in 1:T
        infection_prop = infection_propability
        met_today = meetings
        
        # If it's lockdown
        for lockdown in lockdowns
            if lockdown[1] <= t <= lockdown[2]
                infection_prop = infection_prop/2
                met_today = 1
            end
        end

        # Vaccination
        if t >= vaccination_day
            possible_to_vaccinate = filter(i -> i ∉ infected, unvaccinated)
            for person in 1:vaccinations
                try
                    index = rand(possible_to_vaccinate)
                    append!(vaccinated, index)
                    filter!(i -> i != index, unvaccinated)
                    filter!(i -> i != index, possible_to_vaccinate)
                    vaccination_days[index] = t
                catch ArgumentError
                    continue
                end
            end
        end

        # For each person
        for row in 1:size
            for person in 1:size

                index = size*(person-1) + row
                
                # If person is exposed and incubation time has ended, change his status to infected
                if population[index] == 2 && t - infection_days[index] >= incubation_time
                    population[index] = 3
                    if index ∈ vaccinated
                        if rand()<symptoms_prop/5
                            append!(infected, index)
                        else
                            append!(infected_asymptomatic, index)
                        end
                    elseif rand()<symptoms_prop
                        append!(infected, index)
                    else
                        append!(infected_asymptomatic, index)
                    end
                    filter!(i -> i != index, exposed)
                end

                # If vaccine immunity time has ended
                if t - vaccination_days[index] >= vaccine_immunity_time
                    append!(unvaccinated, index)
                    filter!(i -> i != index, vaccinated)
                end
                
                # If the person is infected
                if population[row, person] == 3
                    
                    if index ∈ infected_asymptomatic

                        # For each met person from the neighbourhood
                        for met_person in 1:met_today
                            inf_prop = infection_propability
                            m = rand(-1:1)
                            n = rand(-1:1)
                            new_infected_index = size * (person + n - 1) + row + m

                            if new_infected_index ∈ vaccinated
                                inf_prop = inf_prop/4
                            end

                            try
                                if population[new_infected_index] == 1 && rand()<inf_prop
                                    population[new_infected_index] = 2
                                    append!(exposed, new_infected_index)
                                    filter!(i -> i != new_infected_index, susceptible)
                                    infection_days[new_infected_index] = t

                                elseif population[new_infected_index] == 4
                                    time_from_recovery = t - recovery_days[new_infected_index]
                                    full_immunity_time = floor(0.3 * vaccine_immunity_time)
                                    inf_prop = inf_prop * (time_from_recovery - full_immunity_time) / (immunity_time - full_immunity_time)
                                    if time_from_recovery >= full_immunity_time && rand()<inf_prop
                                        population[new_infected_index] = 2
                                        append!(exposed, new_infected_index)
                                        filter!(i -> i != new_infected_index, recovered)
                                        infection_days[new_infected_index] = t
                                    end
                                end
                            catch BoundsError
                                continue
                            end
                        end
                    end
                    
                    if rand()<recovery_prop
                        population[index] = 4
                        append!(recovered, index)
                        filter!(i -> i != index, infected)
                        filter!(i -> i != index, infected_asymptomatic)
                        recovery_days[index] = t

                    elseif index ∈ infected && rand()<death_prop
                        population[index] = 0
                        append!(dead, index)
                        filter!(i -> i != index, infected)
                    end
                
                # If person looses immunity
                elseif population[index] == 4 && t - recovery_days[index] >= immunity_time
                    population[index] = 1
                    append!(susceptible, index)
                    filter!(i -> i != index, recovered)
                end
            end
        end
        total_infected_number = length(infected) + length(infected_asymptomatic)
        deaths = length(dead)
        append!(total_infected_record, total_infected_number)
        append!(infected_record, length(infected))
        append!(dead_record, deaths)
        
        if display_heatmap
            heatmap(population,
                title="Day: $t    Deaths: $deaths",
                color=[:black, :gray, :yellow, :orange, :green],
                clim=(0, 4),
                size=(650, 650),
                aspectratio=1
            )
        end
    end
    deaths = length(dead)

    if display_plot
        plot(0:T, total_infected_record, title="Deaths: $deaths", legend=false)
        plot!(0:T, dead_record)
        plot!(0:T, infected_record) |> display
    end

    if display_heatmap
        gif(anim, "epidemic.gif", fps=15) |> display
    end

    return [deaths, infected_record]
end


size = 100
N0 = 10
meetings = 3
incubation_time = 3
immunity_time = 100
lockdowns = [[100, 200]]
vaccination_day = 150
vaccinations = 0.002
vaccine_immunity_time = 180
death_prop = 0.001
recovery_prop = 0.05
infection_propability = 0.6
symptoms_prop = 0.5
T = 400

area_epidemic_simulation(size, N0, meetings, incubation_time, immunity_time, lockdowns,
        vaccination_day, vaccinations, vaccine_immunity_time, death_prop, recovery_prop, infection_propability, symptoms_prop, T)
