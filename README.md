# PWM

<p>
    <a href=".">
      <img src="https://img.shields.io/badge/RTL%20dev-done-green?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/VCS%20sim-done-green?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/FPGA%20verif-no%20start-wheat?style=flat-square">
    </a>
    <a href=".">
      <img src="https://img.shields.io/badge/Tapeout%20test-no%20start-wheat?style=flat-square">
    </a>
</p>

## Features
* 4 channels output compare with edge aligned
* Programmable prescaler
    * max division factor is up to 2^16
    * can be changed ongoing
* 16-bit programmable count up timer counter and compare register
* Auto reload counter
* Maskable overflow interrupt
* Static synchronous design
* Full synthesizable

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```