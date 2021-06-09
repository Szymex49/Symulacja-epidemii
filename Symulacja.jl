using Plots


"Simulate the epidemic using given parameteres.
Display the plot of infected number and the animation of epidemic progress.
Return a vector containing total deaths and maximum infected with symptoms number."
function area_epidemic_simulation(size, N0, meetings, incubation_time, immunity_time, lockdowns,
    vaccination_day, vaccinations, vaccine_immunity_time,
    death_prop, recovery_prop, infection_propability, symptoms_prop, move_propability, T,
    display_heatmap=true, display_plot=true)
    # 0 - dead
    # 1 - susceptible
    # 2 - exposed
    # 3 - infected
    # 4 - recovered

    # Conteners for each state
    dead = []
    susceptible = collect(1:size^2)
    exposed = []
    infected = []
    infected_asymptomatic = []
    recovered = []
    vaccinated = []
    unvaccinated = collect(1:size^2)

    # Records
    total_infected_record = [N0]
    infected_record = [0]
    dead_record = [0]

    population = ones(size, size)   # Array with each person's state
    infection_days = fill(T, size, size)   # Array with days of infection
    recovery_days = fill(T, size, size)   # Array with days of recovery
    vaccination_days = fill(T, size, size)   # Array with days of vaccination

    vaccinations = floor(vaccinations * size^2)  # Number of vaccinations in one day

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
        move_prop = move_propability
        
        # If it's lockdown, reduce infection propability, meetings and moving propability
        for lockdown in lockdowns
            if lockdown[1] <= t <= lockdown[2]
                if lockdown[3] == 1      # Light lockdown
                    infection_prop = 0.7 * infection_prop
                    met_today = 2
                    move_prop = 0.7 * move_prop
                elseif lockdown[3] == 2  # Heavy lockdown
                    infection_prop = 0.5 * infection_prop
                    met_today = 1
                    move_prop = 0.5 * move_prop
                end
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

                # If vaccine immunity time has ended
                if t - vaccination_days[index] >= vaccine_immunity_time
                    append!(unvaccinated, index)
                    filter!(i -> i != index, vaccinated)
                end
                
                # If person is exposed and incubation time has ended, change her status to infected
                if population[index] == 2 && t - infection_days[index] >= incubation_time
                    population[index] = 3
                    if index ∈ vaccinated   # If person is vaccinated, reduce symptoms propability
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

                # If person is healthy and travels
                if index ∉ vcat(infected_asymptomatic, infected, dead) && rand()<move_prop
                    inf_prop = infection_prop
                    random_person = rand(1:size^2)   # Random met person
                    if random_person ∈ infected_asymptomatic   # If met person is infected asymptopmatic
                        
                        # If travelling person is vaccinated, reduce infection propability
                        if index ∈ vaccinated
                            inf_prop = inf_prop/6
                        end

                        # If travelling person is susceptible
                        if population[index] == 1 && rand()<inf_prop
                            population[index] = 2
                            append!(exposed, index)
                            filter!(i -> i != index, susceptible)
                            infection_days[index] = t
                        
                        # If travelling person is recovered
                        elseif population[index] == 4
                            time_from_recovery = t - recovery_days[index]
                            full_immunity_time = floor(0.3 * immunity_time)
                            inf_prop = inf_prop * (time_from_recovery - full_immunity_time) / (immunity_time - full_immunity_time)
                            if time_from_recovery >= full_immunity_time && rand()<inf_prop
                                population[index] = 2
                                append!(exposed, index)
                                filter!(i -> i != index, recovered)
                                infection_days[index] = t
                            end
                        end
                    end
                end
                
                # If the person is infected
                if population[row, person] == 3
                    
                    # If person is infected asymptomatic, he can travel or stay home
                    if index ∈ infected_asymptomatic
                        
                        # If infected person travels
                        if rand()<move_prop
                            inf_prop = infection_prop
                            random_person = rand(1:size^2)   # Random met person

                            # If met person is vaccinated reduce infection propability
                            if random_person ∈ vaccinated
                                inf_prop = inf_prop/6
                            end

                            # If met person is susceptible
                            if population[random_person] == 1 && rand()<inf_prop
                                population[random_person] = 2
                                append!(exposed, random_person)
                                filter!(i -> i != random_person, susceptible)
                                infection_days[random_person] = t

                            # If met person is recovered
                            elseif population[random_person] == 4
                                time_from_recovery = t - recovery_days[random_person]
                                full_immunity_time = floor(0.3 * immunity_time)
                                inf_prop = inf_prop * (time_from_recovery - full_immunity_time) / (immunity_time - full_immunity_time)
                                if time_from_recovery >= full_immunity_time && rand()<inf_prop
                                    population[random_person] = 2
                                    append!(exposed, random_person)
                                    filter!(i -> i != random_person, recovered)
                                    infection_days[random_person] = t
                                end
                            end
                        
                        # If person stays home
                        else
                            # For each met person from the neighbourhood
                            for met_person in 1:met_today
                                inf_prop = infection_prop
                                m = rand(-1:1)
                                n = rand(-1:1)

                                # If we go out of range
                                if row + m > size || row + m < 1 || person + n > size || person + n < 1
                                    continue
                                end

                                neighbour = size * (person + n - 1) + row + m

                                # If met neighbour is vaccinated, reduce infection propability
                                if neighbour ∈ vaccinated
                                    inf_prop = inf_prop/6
                                end

                                # If neighbour is susceptible
                                if population[row + m, person + n] == 1 && rand()<inf_prop
                                    population[neighbour] = 2
                                    append!(exposed, neighbour)
                                    filter!(i -> i != neighbour, susceptible)
                                    infection_days[neighbour] = t

                                # If neighbour is recovered
                                elseif population[neighbour] == 4
                                    time_from_recovery = t - recovery_days[neighbour]
                                    full_immunity_time = floor(0.3 * immunity_time)
                                    inf_prop = inf_prop * (time_from_recovery - full_immunity_time) / (immunity_time - full_immunity_time)
                                    if time_from_recovery >= full_immunity_time && rand()<inf_prop
                                        population[neighbour] = 2
                                        append!(exposed, neighbour)
                                        filter!(i -> i != neighbour, recovered)
                                        infection_days[neighbour] = t
                                    end
                                end
                            end
                        end
                    end
                    
                    # Infected person can recover
                    if rand()<recovery_prop
                        population[index] = 4
                        append!(recovered, index)
                        filter!(i -> i != index, infected)
                        filter!(i -> i != index, infected_asymptomatic)
                        recovery_days[index] = t
                    
                    # If infected person has symptoms he can die
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
                color=[:black, :lemonchiffon, :orange, :orange, :green],
                clim=(0, 4),
                size=(650, 650),
                aspectratio=1
            )
        end
    end
    deaths = length(dead)
    max_symptoms_infected = maximum(infected_record)

    if display_plot
        plot(0:T, total_infected_record, title="Deaths: $deaths", legend=false)
        plot!(0:T, dead_record)
        plot!(0:T, infected_record) |> display
    end

    if display_heatmap
        gif(anim, "epidemic.gif", fps=15) |> display
    end

    return [deaths, max_symptoms_infected]
end


size = 70
N0 = 10
meetings = 3
incubation_time = 5
immunity_time = 240
lockdowns = []
vaccination_day = 250
vaccinations = 0.004
vaccine_immunity_time = 180
death_prop = 0.002
recovery_prop = 0.04
infection_propability = 0.8
symptoms_prop = 0.5
move_prop = 0.002
T = 300

area_epidemic_simulation(size, N0, meetings, incubation_time, immunity_time, lockdowns,
        vaccination_day, vaccinations, vaccine_immunity_time,
        death_prop, recovery_prop, infection_propability, symptoms_prop, move_prop, T)
