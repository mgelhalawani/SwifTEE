import Foundation
import SGXW

struct MainRunner {

    func main() {
        print("Starting Application...")

        let output = initialize_enclave()
        if output < 0 {
            print("Unalbe to create enclave")
            return
        }
        
        call_printf()

        destroy()

        print("Application Ended")
    }
    
}


let runner = MainRunner()
runner.main()