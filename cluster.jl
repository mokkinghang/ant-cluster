#!/usr/lmp/julia/bin/julia
using Profile

# include("random_potential.jl")
# println("random_potential.jl loaded")
include("ODE_solver_reduced.jl")
println("ODE_solver_reduced.jl loaded")
include("save_data.jl")
println("save_data.jl loaded")

# ARGS = [1D/2D, n, domain, time_max, time_interval, potential_center, potential_sd, A, D2, threshold, 
# freq_plot_intervals, group_name, run_name, mode]
# The argument "mode" can be "n" (no noise) or "s" (simulation). "n" is for creating a standard no-noise file that helps find focus point. 

# 1D Gaussian: 1, 2D Gaussian: 2
const gaussian_dim = ARGS[1]
const n = tryparse(Int64,ARGS[2])
const domain = tryparse(Float64,ARGS[3])
const time_max = tryparse(Float64, ARGS[4])
const time_interval = tryparse(Float64, ARGS[5])
const potential_center = tryparse(Float64, ARGS[6])
const potential_sd = tryparse(Float64, ARGS[7])
const A = tryparse(Float64,ARGS[8])
const D2 = tryparse(Float64,ARGS[9])
const threshold = tryparse(Float64,ARGS[10])
const freq_plot_intervals = tryparse(Int64,ARGS[11])
const group_name = ARGS[12]
const run_name = ARGS[13]
const mode = ARGS[14]

@assert mode == "n" || mode == "s"

println("Parsed the arguments:")
println("group_name: $(group_name)")
println("run_name: $(run_name)")
if gaussian_dim == "1"
    println("Gaussian lens without y-grad")
    println("potential center = $(potential_center), potential sd = $(potential_sd)")
elseif gaussian_dim == "2"
    println("Gaussian lens with y-grad, potential center = ($(potential_center),0),
        potential sd = ($(potential_sd),0)")
end
println("Number of ants, n = $(n)")
println("Domain of simulation: [-$(domain), $(domain)] x [-$(domain), $(domain)]")
println("Simulation time: $(time_max)")
println("Time interval: $(time_interval)")
println("Simulation parameters: A=$A, D2=$(D2), threshold=$(threshold)")
println("Frequency plot dimensions: $(freq_plot_intervals) x $(freq_plot_intervals)")

function create_dir(dir)
    if !isdir(dir)
        mkdir(dir)
    end
end

data_directory = "./data"
json_file_directory = joinpath(data_directory, "data_files")
group_directory = joinpath(json_file_directory, group_name)
create_dir(data_directory)
create_dir(json_file_directory)
create_dir(group_directory)

rho, fourier_interval, seed, sim = 1, 512, 1, "fixed_speed"
const x_min= -1*domain
const x_max = domain
const y_min = -domain
const y_max =domain
const interval_x = fourier_interval
const interval_y = fourier_interval
x, y = range(-domain, length=fourier_interval, domain), range(-domain, length=fourier_interval, domain)

#const r = 0
const β = 1
pot_type = "pheromone"

# Constructing the Gaussian potential and drawing the potential contour plots here
const potential_amp = 1

function v(x,y)
    # Standard normal distribution (Corrected with 1/2 term!)
    function snd(center, sd)
        return exp(-(x-center[1])^2/(2*sd[1]^2)-(y-center[2])^2/(2*sd[2]^2))
    end

    function snd_no_y_grad(center, sd)
        return exp(-((x-center)^2/(2*sd^2)))
    end

    if gaussian_dim == "1"
        return potential_amp*snd_no_y_grad(potential_center, potential_sd)
    elseif gaussian_dim == "2"
        potential_center_tuple = (potential_center, 0)
        potential_sd_tuple = (potential_sd, domain)
        return potential_amp*snd(potential_center_tuple, potential_sd_tuple)
    end
end

# Needed when not using ForwardDiff
# vx(x,y) = -potential_amp*(x-potential_center)*v(x,y)/potential_sd^2

# function vy(x,y)
#     if gaussian_dim == "1"
#         return 0
#     elseif gaussian_dim == "2"
#         return -potential_amp*y*v(x,y)/domain^2
#     end
# end

function simulate(n)
    time_steps, ant_coor_x, ant_coor_y = ode_solver(n, speed, init_pos = pos, init_direction = direction, random_direction = false, eq=pot_type)
    hist = get_freq_array(time_steps, ant_coor_x, ant_coor_y)
    save_data_to_jld2(hist, joinpath(group_directory, "$(run_name).jld2"))
    save_data_to_json(ARGS, joinpath(group_directory, "$(run_name)_parameters.json"))
    focus_idx = find_focus(hist)
    if mode == "n"
        save_data_to_jld2(focus_idx, joinpath(group_directory, "focus_idx.jld2"))
    end
end

# Function to find focus
function find_focus(hist)
    no_noise_density_along_x_axis = hist[:,trunc(Int, freq_plot_intervals/2)]
    focus_x = -domain + (findmax(no_noise_density_along_x_axis)[2]-1)*2*domain/freq_plot_intervals
    focus_coor = (focus_x,0)
    focus_idx = (trunc(Int,(domain+focus_coor[1])/(2*domain/freq_plot_intervals)), trunc(Int, freq_plot_intervals/2))
    return focus_idx
end

# potential = [v(i, j) for j in y, i in x]
# potential_plot = contour(x, y, potential, fill=true, dpi=300)

pos = [ones(n).*(-domain), range(-domain/2, length=n, domain/2)]
const direction = 0.0
const speed = 1.
const time_min = 0.0
tspan = (time_min, time_max)
const alpha_max = nothing

# simulate(5)
# Profile.clear_malloc_data()
simulate(n)
