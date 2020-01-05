import Foundation

class System {
    private var observableAgentID: UUID!
    private var currAgenStates = [UUID: (state: State, target: State, postDate: Date)]()
    private var agents = [Agent]()
    
    
    static let shared = System()
    private init(){}
    
    func initSetup() {
        for _ in 1 ... GenerativeModel.numberOfAgents {
            let agent = Agent()
            register(agent)
            agent.postState()
        }
        observableAgentID = agents.first?.id
    }
    
    func getObservableAgentLatentVector() -> [Float] {
        let agent = agents.first{ (agent) -> Bool in
            return agent.id == observableAgentID
        }
        return agent!.currState.getCurrentLatentVector()
    }
    
    
    func postStateFrom(_ agent:Agent) {
        currAgenStates[agent.id] = (agent.currState, agent.targetState, Date())
    }
 
    fileprivate func register(_ agent: Agent) {
        agents.append(agent)
    }
    
    fileprivate func unregister(_ agent: Agent) {
        currAgenStates.removeValue(forKey: agent.id)
        agents.removeAll { (ag) -> Bool in
            ag.id == agent.id
        }
    }
    
    static func distance(st1: State, st2: State) -> Int {
        var result:Int = 0
        for i in 0 ... GenerativeModel.chromosomeLength - 1 {
            if st1.vals[i] != st2.vals[i] {
                result += 1
            }
        }
        return result
    }
    
    func getTargetStates() -> [State] {
        return currAgenStates.map({ (value) -> State in
            return value.value.target
        })
    }
    
    func getCurrStates() -> [State] {
        return currAgenStates.map({ (value) -> State in
            return value.value.state
        })
    }
        
    func getCurrStates(ecsept: UUID) -> [State] {
        var result = [State]()
        for pair in currAgenStates {
            if pair.key != ecsept {
                result.append(pair.value.state)
            }
        }
        
        return result
    }
    func update()  {
        agents.shuffle()
        for agent in agents {
            agent.mutate()
        }
    }
    
    func getAverageDistanceToTargets() -> Int {
        var sum = 0
        for agent in agents {
            sum += System.distance(st1: agent.targetState, st2: agent.currState)
        }
        return Int(sum / GenerativeModel.numberOfAgents)
    }
    
}

struct State {
    typealias StateVector = [Int]
    let vals: StateVector
    
    init(state: StateVector) {
        vals = state
    }
    
    init() {
        var res = [Int]()
        for _  in 1 ... GenerativeModel.chromosomeLength {
            res.append(Int.random(in: 0 ... GenerativeModel.alphabetLength - 1))
        }
        vals =  res
    }
    
    
    func getCurrentLatentVector() -> [Float] {
        return vals.map { (val) -> Float in
            return Float(val)/Float(GenerativeModel.alphabetLength)
        }
    }
}

class Agent {
    let id: UUID!
    private(set) var currState: State!
    let targetState: State!

    func postState() {
        System.shared.postStateFrom(self)
    }
    
    init() {
        id = UUID()
        currState = State()
        targetState = State()
    }
    
    
    func mutate() {
        let all = System.shared.getCurrStates(ecsept: id)
        var nearest = all.first!
        var currMinDistance = System.distance(st1: targetState, st2: nearest)

        for state in System.shared.getCurrStates(ecsept: id) {
            let currDistance = System.distance(st1: targetState, st2: state)
            if currDistance < currMinDistance {
                nearest = state
                currMinDistance = currDistance
            }
        }
        //crosover
        let crossoverPoint =  Int(Float(GenerativeModel.chromosomeLength - 1) * GenerativeModel.crossoverSelfWeight)
        
        var newStateVals1 = [Int]()
        var newStateVals2 = [Int]()
        for i in 0 ... GenerativeModel.chromosomeLength - 1 {
            newStateVals1.append( i < crossoverPoint ? currState!.vals[i] : nearest.vals[i])
            newStateVals2.append( i < crossoverPoint ? nearest.vals[i] : currState!.vals[i])
        }

        //random mutation
        for _ in 0...GenerativeModel.mutationsNumber - 1{
             let muatationPoint1 = Int.random(in: 0...GenerativeModel.chromosomeLength - 1)
            newStateVals1[muatationPoint1] = Int.random(in: 0 ... GenerativeModel.alphabetLength - 1)
            
            let muatationPoint2 = Int.random(in: 0...GenerativeModel.chromosomeLength - 1)
            newStateVals2[muatationPoint2] = Int.random(in: 0 ... GenerativeModel.alphabetLength - 1)
        }
        let st1 = State(state: newStateVals1)
        let st2 = State(state: newStateVals2)

        
        let dist1 = System.distance(st1: targetState, st2: st1)
        let dist2 = System.distance(st1: targetState, st2: st2)
        currState = dist1 < dist2 ? st1 : st2

        postState()
    }
}


struct GenerativeModel {
    static let chromosomeLength = 128
    static let alphabetLength = 2
    static let numberOfAgents = 16
    
    static let crossoverSelfWeight: Float = 0.5
    static let mutationsNumber = 10
}

let system = System.shared
print("Number of agents: \(GenerativeModel.numberOfAgents)")


system.initSetup()
var averageOverPopulationDistanceToTheTarget = [Int]()
for i in 0 ... 64 {
    print("iteration: \(i)")
    averageOverPopulationDistanceToTheTarget.append(system.getAverageDistanceToTargets())
    system.update()
}

print(averageOverPopulationDistanceToTheTarget)
