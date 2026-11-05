let displayPicture = false;
let tempsrc = '';

function sanitizeUrl(inputUrl) {
	if (typeof inputUrl === 'string' && /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$/.test(inputUrl)) {
		return inputUrl;
	}
	return '';
}

function setLocation(location) {
	if (typeof location === 'string') {
		document.getElementById('location').textContent = location;
	} else if (typeof location === 'object') {
		let formattedLocation = `X: ${location.x.toFixed(
			2
		)}, Y: ${location.y.toFixed(2)}, Z: ${location.z.toFixed(2)}`;
		document.getElementById('location').textContent = formattedLocation;
	}
}

function open(image, location) {
	if (!displayPicture) {
		$('.picture-container').removeClass('hide');
		if (image) {
			image = sanitizeUrl(image);
			if (image) {
				$('.picture').css({ 'background-image': `url("${image}")` });
			} else {
				$('.picture').css({ 'background-image': 'none' });
			}
			tempsrc = image;
		} else {
			$('.picture').css({ 'background-image': 'none' });
		}

		if (typeof location === 'string') {
			$('#location').text(location);
		} else {
			setLocation(location);
		}
		displayPicture = true;
	}
}

function close() {
	if (displayPicture) {
		$('.picture-container').addClass('hide');
		$('#location').html('');
		$('.picture').css({ background: '' });
		displayPicture = false;
		tempsrc = '';
		$.post(`https://${GetParentResourceName()}/close`);
	}
}

function toggleflash(status)
{
	if(status)
	{
		$('#flashstatus').removeClass("off");
		$('#flashstatus').addClass("on");
	}
	else
	{
		$('#flashstatus').removeClass("on");
		$('#flashstatus').addClass("off");
	}
}

$(document).ready(function () {
	window.addEventListener('message', function (event) {
		if (event.data.action === 'Open') {
			open(event.data.image, event.data.location);
			document.getElementById('camera-overlay').classList.remove('hide');
		} else if (event.data.action === 'SetLocation') {
			setLocation(event.data.location);
		} else if (event.data.action === 'showOverlay') {
			document.getElementById('camera-overlay').classList.remove('hide');
		} else if (event.data.action === 'hideOverlay') {
			document.getElementById('camera-overlay').classList.add('hide');
		} else if (event.data.action === 'openPhoto') {
			open(event.data.image, event.data.location);
		} else if (event.data.action === 'toggleFlash') {
			toggleflash(event.data.status);
		}
	});

	document.onkeydown = function (event) {
		if (event.repeat) {
			return;
		}
		switch (event.key) {
			case 'Escape':
				close();
				break;
		}
	};

});
