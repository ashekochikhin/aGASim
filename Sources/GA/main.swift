import Foundation
import Dispatch

class System {
    private var currAgenStates = [UUID: (state: State, target: State, postDate: Date)]()
    private var agents = [Agent]()
    private var serial = DispatchQueue.init(label: "serialGA")
    private var concurent = DispatchQueue.init(label: "concurentGA", qos: .default, attributes: .concurrent, autoreleaseFrequency: .never, target: nil)
    
    static let shared = System()
    private init(){}
    
    func initSetup() {
        for _ in 1 ... GenerativeModel.numberOfAgents {
            let agent = Agent()
            register(agent)
            agent.postState()
        }
    }
    
    func postStateFrom(_ agent:Agent) {
        serial.sync {
            self.currAgenStates[agent.id] = (agent.currState, agent.targetState, Date())
        }
    }
 
    fileprivate func register(_ agent: Agent) {
        self.agents.append(agent)
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
        
    func getCurrStates(ecsept: UUID) -> [State] {
        var result = [State]()
        serial.sync {
            for pair in self.currAgenStates {
                if pair.key != ecsept {
                    result.append(pair.value.state)
                }
            }
        }

        return result
    }
    func update()  {
        agents.shuffle()
        
        let group = DispatchGroup.init()
        for agent in agents {
            group.enter()
            concurent.async {
                agent.mutate()
                group.leave()
            }
        }
        group.wait()
    }
    
    func getMedianDistanceToTargets() -> Float {
        var distances = [Int]()
        let group = DispatchGroup.init()
        for agent in agents {
            group.enter()
            concurent.async {
                let currdistance = System.distance(st1: agent.targetState, st2: agent.currState)
                self.serial.sync {
                    distances.append(currdistance)
                }
                group.leave()
            }
        }
        group.wait()
        return calculateMedian(array: distances)
    }
    
    private func calculateMedian(array: [Int]) -> Float {
        let sorted = array.sorted()
        if sorted.count % 2 == 0 {
            return Float((sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1])) / 2
        } else {
            return Float(sorted[(sorted.count - 1) / 2])
        }
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
    static let numberOfAgents = 32
    
    static let crossoverSelfWeight: Float = 0.5
    static let mutationsNumber = 10
}

let system = System.shared
system.initSetup()
var amedianOverPopulationDistanceToTheTarget = [Float]()
for i in 0 ... 32 {
    print("iteration: \(i)")
    amedianOverPopulationDistanceToTheTarget.append(system.getMedianDistanceToTargets())
    system.update()
}

print(amedianOverPopulationDistanceToTheTarget)
func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
let str = "\(amedianOverPopulationDistanceToTheTarget)"
let filename = getDocumentsDirectory().appendingPathComponent("output_\(GenerativeModel.numberOfAgents).txt")

do {
    try str.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
} catch {
    // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
}
