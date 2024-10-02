window.addEventListener('DOMContentLoaded', function() {
    function interpolateColor(color1, color2, factor) {
        const result = color1.slice();
        for (let i = 0; i < 3; i++) {
            result[i] = Math.round(result[i] + factor * (color2[i] - color1[i]));
        }
        return result;
    }

    function rgbToCss(rgb) {
        return `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`;
    }

    function formatMoney(amount) {
        return amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    }

    const progressCircle = document.getElementById('tachometer-progress');
    const circleLength = progressCircle.getTotalLength();

    progressCircle.style.strokeDasharray = circleLength;
    progressCircle.style.strokeDashoffset = circleLength;

    window.addEventListener('unload', function() {
        document.body.style.visibility = 'hidden';
        document.body.style.opacity = '0';
    });

    let isHidingTacho = false;
    let lastClipAmmo = null;
    let lastTotalAmmo = null;

    
    const ammoContainer = document.getElementById('ammo-container');
    const ammoClipCount = document.getElementById('ammo-clip-count');
    const ammoTotalCount = document.getElementById('ammo-total-count');
    const speedTextElement = document.getElementById('speed-text');
    const leftBlinker = document.getElementById('left-blinker');
    const rightBlinker = document.getElementById('right-blinker');
    const fuelPercent = document.getElementById('fuel-percent');
    const fuelBar = document.getElementById('fuel-bar');
    const engineCondition = document.getElementById('engine-condition');
    const highBeamIcon = document.getElementById('high-beam-icon');
    const lowBeamIcon = document.getElementById('low-beam-icon');
    const lightsOffIcon = document.getElementById('lights-off-icon');
    const micIcon = document.getElementById('mic').querySelector('i');
    const radioIcon = document.getElementById('radio').querySelector('i');
    const jobElement = document.getElementById('job');
    const playerIdElement = document.getElementById('playerId');
    const voiceLevelIndicator = document.getElementById('voice-level-indicator');
    const moneyElement = document.getElementById('money');
    const bankElement = document.getElementById('bank');
    const blackMoneyElement = document.getElementById('blackmoney');
    const locationElement = document.getElementById('location');
    const hungerPercentElement = document.getElementById('hunger-percent');
    const thirstPercentElement = document.getElementById('thirst-percent');
    const hungerFill = document.getElementById('hunger-fill');
    const thirstFill = document.getElementById('thirst-fill');
    const tachoElement = document.getElementById('tacho');
    const roadIcon = document.getElementById('road-icon');
    const serverTimeElement = document.getElementById('server-time');
    const serverDateElement = document.getElementById('server-date');
    const serverPlayersElement = document.getElementById('server-players');

    window.addEventListener('message', function(event) {
        const data = event.data;

        switch (data.type) {
            case "updateSpeed":
                updateSpeed(data);
                break;
            case "updateIndicators":
                updateIndicators(data);
                break;
            case "updateAmmo":
                updateAmmo(data);
                break;
            case "showAmmoHUD":
                showAmmoHUD();
                break;
            case "hideAmmoHUD":
                hideAmmoHUD();
                break;
            case "updateFuel":
                updateFuel(data);
                break;
            case "updateEngineCondition":
                updateEngineCondition(data);
                break;
            case "updateLightsMode":
                updateLightsMode(data);
                break;
            case "showHUD":
                document.body.style.visibility = 'visible';
                document.body.style.opacity = '1';
                break;
            case "hideHUD":
                document.body.style.visibility = 'hidden';
                break;
            case "updateDateTime":
                updateDateTime(data);
                break;
            case "updatePlayerCount":
                updatePlayerCount(data);
                break;
            case "updateMicStatus":
                updateMicStatus(data);
                break;
            case "updateRadioStatus":
                updateRadioStatus(data);
                break;
            case "update":
                updateHUD(data);
                break;
            case "showTachoWithAnimation":
                showTachoWithAnimation();
                break;
            case "hideTachoWithAnimation":
                hideTachoWithAnimation();
                break;
            case "updateAutopilotStatus":
                updateAutopilotStatus(data);
                break;
        }
    });

    function updateSpeed(data) {
        const speed = data.speed;
        const maxSpeed = data.maxSpeed || 300;
        const percentage = Math.min(speed / (maxSpeed + 50), 1);
        const offset = circleLength * (1 - percentage);
        progressCircle.style.strokeDashoffset = offset;

        const formattedSpeed = speed.toString().padStart(3, '0');
        let formattedSpeedText = '';
        let firstNonZeroFound = false;

        const startColor = [255, 255, 255];
        const endColor = [83, 0, 245];
        const speedFactor = Math.min(speed / maxSpeed, 1);

        const color = interpolateColor(startColor, endColor, speedFactor);
        const textShadow = `0 0 ${10 * speedFactor}px ${rgbToCss(color)}`;

        for (let i = 0; i < formattedSpeed.length; i++) {
            const digit = formattedSpeed[i];

            if (digit === '0' && !firstNonZeroFound) {
                formattedSpeedText += `<span class="greyed-zero" style="text-shadow: none;">0</span>`;
            } else {
                firstNonZeroFound = true;
                formattedSpeedText += `<span style="color: ${rgbToCss(color)}; text-shadow: ${textShadow};">${digit}</span>`;
            }
        }

        speedTextElement.innerHTML = formattedSpeedText;
    }

    function updateIndicators(data) {
        const leftActive = data.left;
        const rightActive = data.right;
        const sync = data.sync;

        if (sync) {
            if (leftActive && rightActive) {
                leftBlinker.classList.remove('active');
                rightBlinker.classList.remove('active');

                setTimeout(() => {
                    leftBlinker.classList.add('active');
                    rightBlinker.classList.add('active');
                }, 50);
            } else {
                leftBlinker.classList.remove('active');
                rightBlinker.classList.remove('active');
            }
        } else {
            leftBlinker.classList.toggle('active', leftActive);
            rightBlinker.classList.toggle('active', rightActive);
        }
    }

    function updateAmmo(data) {
        lastClipAmmo = data.clip;
        lastTotalAmmo = data.total;

        ammoClipCount.innerText = lastClipAmmo;
        ammoTotalCount.innerText = lastTotalAmmo;
    }

    function showAmmoHUD() {
        if (lastClipAmmo !== null && lastTotalAmmo !== null) {
            ammoClipCount.innerText = lastClipAmmo;
            ammoTotalCount.innerText = lastTotalAmmo;
        }

        ammoContainer.style.display = 'flex';
        ammoContainer.classList.remove('hide-ammo');
        ammoContainer.classList.add('show-ammo');
    }

    function hideAmmoHUD() {
        ammoContainer.classList.remove('show-ammo');
        ammoContainer.classList.add('hide-ammo');

        setTimeout(() => {
            ammoContainer.style.display = 'none';
        }, 300);
    }

    function updateFuel(data) {
        const fuelLevel = data.fuel;
        fuelPercent.innerText = fuelLevel + '%';
        fuelBar.style.width = fuelLevel + '%';

        const fuelColorStart = [83, 0, 245];
        const fuelColorEnd = [255, 0, 0];
        const fuelFactor = (100 - fuelLevel) / 100;
        const fuelColor = rgbToCss(interpolateColor(fuelColorStart, fuelColorEnd, fuelFactor));

        fuelBar.style.backgroundColor = fuelColor;
        fuelBar.style.boxShadow = `0 0 10px ${fuelColor}, 0 0 20px ${fuelColor}`;
    }

    function updateEngineCondition(data) {
        const engineHealth = data.engineHealth;

        const purpleColor = [83, 0, 245];
        const redColor = [255, 0, 0];

        const factor = 1 - (engineHealth / 100);
        const interpolatedColor = interpolateColor(purpleColor, redColor, factor);

        engineCondition.style.color = rgbToCss(interpolatedColor);

        if (engineHealth < 15) {
            engineCondition.classList.add('blink-red');
        } else {
            engineCondition.classList.remove('blink-red');
        }
    }

    function updateLightsMode(data) {
        const lightsMode = data.lightsMode;

        highBeamIcon.style.display = 'none';
        lowBeamIcon.style.display = 'none';
        lightsOffIcon.style.display = 'none';

        if (lightsMode === 0) {
            lightsOffIcon.style.display = 'block';
        } else if (lightsMode === 1) {
            lowBeamIcon.style.display = 'block';
        } else if (lightsMode === 2) {
            highBeamIcon.style.display = 'block';
        }
    }

    function updateDateTime(data) {
        serverTimeElement.innerText = data.time;
        serverDateElement.innerText = data.date;
    }

    function updatePlayerCount(data) {
        serverPlayersElement.innerText = `${data.online}/${data.max}`;
    }

    function updateMicStatus(data) {
        micIcon.style.color = data.mic ? "#5300f5" : "#c2c2c2";
    }

    function updateRadioStatus(data) {
        radioIcon.style.color = data.radio ? "#5300f5" : "#c2c2c2";
    }

    function updateHUD(data) {
        jobElement.innerText = `${data.job} - ${data.grade}`;
        playerIdElement.innerHTML = `<i class="fas fa-id-badge"></i> ${data.playerId}`;

        voiceLevelIndicator.innerHTML = '';
        const level = data.voiceLevel;
        for (let i = 1; i <= 3; i++) {
            const levelBar = document.createElement('div');
            if (i <= level) {
                levelBar.classList.add('active');
            }
            voiceLevelIndicator.appendChild(levelBar);
        }

        moneyElement.innerHTML = `$${formatMoney(data.money)} <i class="fas fa-wallet"></i>`;
        bankElement.innerHTML = `$${formatMoney(data.bank)} <i class="fas fa-credit-card"></i>`;
        blackMoneyElement.innerHTML = `$${formatMoney(data.blackMoney)} <i class="fas fa-money-bill-wave"></i>`;

        locationElement.innerHTML = `<i class="fas fa-map-marker-alt"></i> ${data.street} | PLZ: ${data.postalCode}`;

        const hungerPercent = data.hunger;
        const thirstPercent = data.thirst;

        hungerPercentElement.innerText = hungerPercent + '%';
        thirstPercentElement.innerText = thirstPercent + '%';

        hungerFill.style.width = hungerPercent + '%';
        thirstFill.style.width = thirstPercent + '%';

        const hungerColor = [83, 0, 245];
        const thirstColor = [83, 0, 245];
        const redColor = [255, 0, 0];

        const hungerFactor = (100 - hungerPercent) / 100;
        const thirstFactor = (100 - thirstPercent) / 100;

        const hungerCssColor = rgbToCss(interpolateColor(hungerColor, redColor, hungerFactor));
        const thirstCssColor = rgbToCss(interpolateColor(thirstColor, redColor, thirstFactor));

        hungerFill.style.backgroundColor = hungerCssColor;
        thirstFill.style.backgroundColor = thirstCssColor;

        hungerFill.style.boxShadow = `0 0 10px ${hungerCssColor}, 0 0 20px ${hungerCssColor}`;
        thirstFill.style.boxShadow = `0 0 10px ${thirstCssColor}, 0 0 20px ${thirstCssColor}`;
    }

    function showTachoWithAnimation() {
        if (isHidingTacho) {
            isHidingTacho = false;
            tachoElement.style.animation = 'none';
        }

        tachoElement.style.display = 'flex';

        setTimeout(() => {
            tachoElement.style.animation = 'slideIn 0.5s forwards';
        }, 10);
    }

    function hideTachoWithAnimation() {
        if (!isHidingTacho) {
            isHidingTacho = true;
            tachoElement.style.animation = 'slideOut 0.5s forwards';

            setTimeout(() => {
                if (isHidingTacho) {
                    tachoElement.style.display = 'none';
                    isHidingTacho = false;
                }
            }, 500);
        }
    }

    function updateAutopilotStatus(data) {
        roadIcon.style.color = data.active ? "#5300f5" : "#c2c2c2";
    }
});
