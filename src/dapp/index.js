
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(flight, (error, result) => {
                console.log('result ==> ', result)
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });
        })

        // funds airline
        contract.fundAirline((error, result) => {
            console.log('ferror ==> ',error, 'fresult ==> ',result)
        })

        //Register predefine flights
        let flightNos = document.querySelectorAll('#flight>span')
        let flightkey = document.querySelectorAll('#flightKey')
        for(let flightNo = 0; flightNo < flightNos.length; flightNo++) {

            contract.registerFlights(flightNos[flightNo].innerText, (error, result) => {
                flightkey[flightNo].value = result.events.FlightRegistered.returnValues[2]
            })
        }


        document.addEventListener('click', event => {
            event.preventDefault()
            // Buy insurance
            
            if(event.target.id == "buyInsurance") {
                let parentNode = event.target.parentNode
                let amount = parentNode.querySelector('#value').value
                let flightKey = parentNode.querySelector('#flightKey').value

                contract.buyInsurance(flightKey, amount, (error, {InsurancePurchased}) => {
                    display('Purchase Insurance', 'Show insurance Purchase status', [{label: 'Insurance Purchase status', error: error, value: InsurancePurchased.returnValues[0]}])
                })
            } else if(event.target.id = "withdrawPayment") {
                contract.payPassenger((error, result) => {
                    // display('Withdraw', 'Show withdrawal status', [{label: 'Withdrawal status', error: error, value: InsurancePurchased.returnValues[0]}])
                })
            }

            // Withdrawal 

        })

    });
    
})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.append(section);

}







