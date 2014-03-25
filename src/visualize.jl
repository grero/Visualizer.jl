using Tk
using Winston
using Spiketrains
import Spiketrains.plot!

type NavigationState
    state::Integer
    p
    overlay::Bool
end

type NavigationControls
    state
end

visualize(X,title::String) = visualize(X,800,600,title)
visualize(X) = visualize(X,800,600,"Visualizer")
function visualize(X,width::Integer, height::Integer,title::String; overlay::Bool=false)
    #figure out what kind of plots we are creating
    m3 = methodswith(Table)
    if typeof(X) <: (Any...)
        if overlay == false
            p = Table(1,length(X))
            navstate = NavigationState(1, p,overlay)
            for i=1:length(X)
                if typeof(X[i]) <: Array
                    m1 = methodswith(typeof(X[i][1]))
                    if ~isempty(intersect(m1,m3))
                        pp = Table(1,length(names(X[i][1]))-1)
                        navstate.p[1,i] = pp
                    else
                        navstate.p[1,i] = FramedPlot()
                    end
                else
                    navstate.p[1,i] = FramedPlot()
                end
            end
        else
            navstate = NavigationState(1,FramedPlot(),overlay)
        end
    else 
    #figure out whether we are using FramedPlot or Table; something of a hack
        if typeof(X) <: Array
            m1 = methodswith(typeof(X[1]))
            if ~isempty(intersect(m1,m3))
                #we found a method taking Table, so use table
                p = Table(1,length(names(X[1]))-1)
                navstate = NavigationState(1, p)
            else
                navstate = NavigationState(1, FramedPlot())
            end
        else
            navstate = NavigationState(1, FramedPlot())
        end
    end

    win = Toplevel(title,width,height)
    fwin = Frame(win)
    pack(fwin, expand=true, fill="both")
    c = Canvas(fwin, width,height)
    grid(c,1,1, sticky="nsew")
    fctrls = Frame(fwin)
    grid(fctrls,2,1,sticky="sw",padx=5,pady=5)
    grid_columnconfigure(fwin,1,weight=1)
    grid_rowconfigure(fwin,1,weight=1)
    prev = Button(fctrls,"Prev")
    grid(prev,1,1)
    en = Entry(fctrls, width=5)
    navctrls = NavigationControls(en)
    grid(en,1,2)
    set_value(en,string(navstate.state))
    nxt = Button(fctrls,"Next")
    grid(nxt,1,3)
    sav = Button(fctrls,"Save")
    grid(sav,1,4)
    bind(prev, "command", path -> plottest(c,navstate,navctrls,X,navstate.state-1))
    bind(nxt, "command", path -> plottest(c,navstate, navctrls, X,navstate.state+1))
    bind(en, "<Return>", path -> updatef(navstate,navctrls,c,X))
    bind(sav, "command", path -> saveplot(navstate))
    plottest(c,navstate,navctrls, X,navstate.state) 
end

function saveplot(navstate::NavigationState)
    cc = navstate.state
    win = Toplevel()
    f = Frame(win)
    pack(f,expand=true,fill="both")
    l = Label(f, "File name: ")
    ee = Entry(f, width=15)
    set_value(ee, "/tmp/cell$cc.pdf")
    ok = Button(f, "OK")
    cancel = Button(f, "Cancel")
    grid(l,1,1)
    grid(ee, 1,2, pady=5)
    grid(cancel, 2,1)
    grid(ok, 2,2)

    function set_close!(navstate::NavigationState)
        file(navstate.p,string(get_value(ee)),width=800,height=600)
        destroy(win)
    end
    bind(ee, "<Return>", path->set_close!(navstate))
    bind(ok,"command", path->set_close!(navstate))
    bind(cancel, "command", path->destroy(win))
end

function updatef(navstate::NavigationState, navctrls::NavigationControls,c,X)
    navstate.state = int(get_value(navctrls.state))
    plottest(c,navstate,navctrls,X,navstate.state)
end

function plottest(c,navstate::NavigationState,navctrls::NavigationControls,X,i::Integer)
    #check if we are plotting several variables simulataneously
#    if typeof(X) <: (Any...)
#        p = Table(1,length(X))
#    else
#        if typeof(X) <: Array{Any,1}
#            #check if the type we are plotting uses FramedPlot or Table
#            m2 = methodswith(FramedPlot)
#            m3 = methodswith(Table)
#            m1 = methodswith(typeof(X[1]))
#            if ~isempty(intersect(m1,m3))
#                #this is pretty ad-hoc; assuming that all fields of X[i] should be printed
#                p = Table(1,length(names(X[1]))-1)
#            else
#                p = FramedPlot()
#            end
#        else
#            p = FramedPlot()
#        end
#    end
    p = navstate.p
    if typeof(p) <: FramedPlot
        p.content1 = Winston.PlotComposite()
    end
    plot!(p,X,i)
    Winston.display(c,p)
    reveal(c)
    Tk.update()
    navstate.state = i
    #navstate.p = p
    set_value(navctrls.state, string(i))
end

#convience function for plotting simple matrices
function plot!{T<:Real}(p::FramedPlot, X::Array{T,2},i::Integer)
    if i > 0 && i <= size(X,2)
        #complicated way of clearing the plot content
        p.content1 = Winston.PlotComposite()
        plot(p, X[:,i])
        setattr(p.x2,"draw_axis",false)
        setattr(p.y2,"draw_axis",false)
        return p
    end
end

#array of objects
function plot!{T}(p, X::Array{T,1}, i::Integer)
    if i > 0 && i <= length(X)
        plot!(p, X[i])
        #setattr(p.x2,"draw_axis",false)
        #setattr(p.y2,"draw_axis",false)
        return p
    end
end

function plot!(p::FramedPlot, X::Dict{Any, Any},i::Integer)
    x = pop!(X,"x", (0,1))
    qkeys = collect(keys(X))
    if i > 0 && i <= length(qkeys) 
        plot(p,x,X[qkeys[i]])
        setattr(p.x2,"draw_axis",false)
        setattr(p.y2,"draw_axis",false)
        return p
    end
end

function plot!(p::Table, X::(Any...),i::Integer)
    for j=1:length(X)
        #p[1,j] = FramedPlot()
        #HACK: ideally I want to just call 'clear(p)' here, but that doesn't seem to work
        if typeof(p[1,j]) <: FramedPlot
            p[1,j] = FramedPlot()
        elseif typeof(p[1,j]) <: Table
            p[1,j] = Table(p[1,j].rows, p[1,j].cols)
        end
        plot!(p[1,j],X[j],i)
    end
end

function plot!(p::FramedPlot, X::(Any...), i::Integer)
    plot!(p,X[1],i)
    hold(true)
    for j=2:length(X)
        plot!(p,X[j],i)
    end
end

function plottest(c,a)
    #test
    x = linspace(0.0,10.0,1001)
    y = sin(a*x)
    p = FramedPlot()
    add(p,Curve(x,y,"color","red"))
    Winston.display(c,p)
    reveal(c)
    Tk.update()
end
