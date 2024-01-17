import Foundation
import SGXW

struct MainRunner {

    func main() {
        print("in main")
        runProcess()
        print("Done")
    }
}


let runner = MainRunner()
runner.main()