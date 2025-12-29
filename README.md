<div align="center">
    <h1>BatteryPro - Battery Care & Monitoring</h1>
</div>

_MacOS menu bar tool to limit maximum charging percentage and improve battery lifespan._

> Originally based on [AlDente](https://github.com/davidwernhart/AlDente), BatteryPro has evolved into a distinct open-source project with enhanced features like Manual Bypass and improved SMC compatibility.

## Why do I need this?
Li-Ion batteries (like the one in your MacBook) last the longest when operating between 20 and 80 percent. Keeping your battery at 100% at all times can shorten the lifespan of your MacBook significantly.
More information can be found at [Battery University](https://batteryuniversity.com/article/bu-415-how-to-charge-and-when-to-charge).

## Features
* **Charge Limiter** - Automatically stops charging when your battery reaches a set percentage (e.g., 80%).
* **Manual Bypass** - Instantly stop charging and run directly from the power adapter. Perfect for when you're plugged in for long periods and want to hold the current percentage.
* **Discharge** - Allows your MacBook to run completely on battery power even while plugged in, letting you actively discharge to a healthier percentage.

## Download
You can download the app from GitHub: <https://github.com/StephenLovino/BatteryPro/releases>

## How to use
When the installation is finished, enter your desired max. charging percentage by clicking on the BatteryPro icon on your menu bar. 

> [!NOTE]
> **Status Update Delay**: When enabling/disabling charging or using the Manual Bypass, macOS may take a few seconds to a minute to update the visual battery icon status (e.g., from "Charging" to "Not Charging"). This is normal system behavior; the actual power flow changes instantly.

You can check if it's working by setting the max. percentage to e.g., 80%. After a while, clicking on your battery icon will report "Battery is not charging" if you have more than ≈73% left, even though your charger is connected. Notice that in this state, your MacBook is still powered by the charger, but the battery is bypassed and not charging anymore.

> [!IMPORTANT]
> Keeping your battery at a lower percentage, such as under 80%, for weeks without doing full cycles (100%-0%) can result in a disturbed battery calibration. When this happens, your MacBook might turn off with 40-50% left, or your battery capacity will drop significantly. However, this is only due to a disturbed battery calibration and not because of a faulty or degraded battery. To avoid this issue, we recommend doing at least one full cycle (0%-100%) every two weeks. Even if your battery calibration gets disturbed, doing 4+ full cycles will recalibrate your battery, and the capacity will go up again.

## Technical Documentation

For developers working on this project, see **[TECHNICAL_DOCUMENTATION.md](docs/TECHNICAL_DOCUMENTATION.md)** for comprehensive documentation on architecture, SMC integration, and building the project.

## Other tools used in this project:
* <https://github.com/beltex/SMCKit>
* <https://github.com/sindresorhus/LaunchAtLogin>
* <https://github.com/andreyvit/create-dmg>

## Disclaimer
I do not take any responsibility for any sort of damage as a result of using this tool! Although this had no negative side effects for me and thousands of others, this tool still taps into some very low-level system functions that are not meant to be tampered with. Use it at your own risk!

## License
Copyright(c) 2021 AppHouseKitchen

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
