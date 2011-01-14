#import "AVFoundationVideoGrabber.h"
#import "ofiPhoneVideoPlayer.h"
#import "ofxiPhoneExtras.h"


AVFoundationVideoGrabber * videoPlayer;
CGImageRef currentFrameRef;

long nextMovieID = 0;

ofiPhoneVideoPlayer::ofiPhoneVideoPlayer() {
	videoPlayer=NULL;
	videoWasStopped=false;
	
	width = 0;
	height = 0;
	playbackSpeed=1;
	
	myID = nextMovieID;
	nextMovieID++;
}

//----------------------------------------

ofiPhoneVideoPlayer::~ofiPhoneVideoPlayer() {
	close();
}

//----------------------------------------

bool ofiPhoneVideoPlayer::loadMovie(string name) {
	
	if(videoPlayer != NULL)
		close();
	
	videoPath = name;
	initWithPath(videoPath);
	
	if(videoPlayer != NULL)
		if(! [videoPlayer isInErrorState])
			return true;
	return false;
}

//----------------------------------------

void ofiPhoneVideoPlayer::close() {
	if(videoPlayer != NULL)
		[videoPlayer release];
	videoPlayer = NULL;
}

//----------------------------------------

void ofiPhoneVideoPlayer::play() {
	
	lastUpdateTime=ofGetElapsedTimef();
	
	if(videoPlayer != NULL)
		[videoPlayer play];
	else if(videoWasStopped || getIsMovieDone()) {
		[videoPlayer release];
		initWithPath(videoPath);
		play();
	}
	else
		ofLog(OF_LOG_WARNING, "ofiPhoneVideoPlayer: video is not loaded, cannot be played");
}

//----------------------------------------

void ofiPhoneVideoPlayer::stop() {
	if(videoPlayer != NULL) {
		[videoPlayer pause];
		close();
		videoWasStopped=true;
	}
	
	ofLog(OF_LOG_WARNING, "ofiPhoneVideoPlayer: video is not loaded, cannot be stopped");
}		

//----------------------------------------

bool ofiPhoneVideoPlayer::isFrameNew() {
	if(videoPlayer != NULL) {
		return [videoPlayer hasNewFrame];
	}	
	return false;
}

//----------------------------------------

unsigned char * ofiPhoneVideoPlayer::getPixels() {
	if(videoPlayer != NULL)
	{
		updateCurrentFrameRef();
		ofxiPhoneCGImageToPixels(currentFrameRef, pixels);
		return pixels;
	}
	
	return NULL;
}

ofTexture * ofiPhoneVideoPlayer::getTexture()
{
	if(videoPlayer != NULL)
	{
		CVImageBufferRef imageBuffer = [videoPlayer getCurrentFrame]; 

		CVPixelBufferLockBaseAddress(imageBuffer,0); 

		uint8_t *bufferPixels = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
		
		if(width != min(size_t(1024),CVPixelBufferGetWidth(imageBuffer))) {
			if(videoTexture.bAllocated())
				videoTexture.clear();
			
			width = min(size_t(1024),CVPixelBufferGetWidth(imageBuffer)); 
			height = min(size_t(1024),CVPixelBufferGetHeight(imageBuffer));

			videoTexture.allocate(width, height, GL_RGBA);
		}
		
		videoTexture.loadData(bufferPixels, width, height, GL_BGRA);
		
		// unlock the image buffer
		CVPixelBufferUnlockBaseAddress(imageBuffer,0);
		
		return &videoTexture;
	}
	
	return NULL;
}

//----------------------------------------

float ofiPhoneVideoPlayer::getWidth() {
	if(videoPlayer != NULL)
		return width;
	
	ofLog(OF_LOG_WARNING, "ofiPhoneVideoPlayer: video is not loaded, cannot getWidth");
	return 0;
}

//----------------------------------------

float ofiPhoneVideoPlayer::getHeight() {
	if(videoPlayer != NULL)
		return height;
	
	ofLog(OF_LOG_WARNING, "ofiPhoneVideoPlayer: video is not loaded, cannot getHeigt");
	return 0;
}

//----------------------------------------

bool ofiPhoneVideoPlayer::isPaused() {
	if(videoPlayer != NULL)
		return [videoPlayer isPaused];
	
	cerr<<"video is not loaded - isPaused"<<endl;
	return false;
}

//----------------------------------------

bool ofiPhoneVideoPlayer::isLoaded() {
	if(videoPlayer != NULL && ! [videoPlayer isInErrorState])
		return true;
	else
		return false;
}

//----------------------------------------

bool ofiPhoneVideoPlayer::isPlaying() {
	if(videoPlayer != NULL) {
		if([videoPlayer isFinished] || [videoPlayer isPaused] || [videoPlayer isInErrorState])
			return false;
		else
			return true;
	}
	
	return false;
}

void ofiPhoneVideoPlayer::update() {
	if(videoPlayer != NULL) {
		float t = ofGetElapsedTimef();
		[videoPlayer updateWithElapsedTime:(t-lastUpdateTime)*playbackSpeed];
		lastUpdateTime=t;
	}
}

float ofiPhoneVideoPlayer::getPosition() {
	if(videoPlayer != NULL)
		return [videoPlayer getVideoPosition];
	else
	return 0;
}

float ofiPhoneVideoPlayer::getDuration() {
	if(videoPlayer != NULL)
		return [videoPlayer getDuration];
	else
		return 0;

}

bool ofiPhoneVideoPlayer::getIsMovieDone() {
	if(videoPlayer != NULL)
		return [videoPlayer isFinished];
	else
		return true;
}

void ofiPhoneVideoPlayer::setPaused(bool bPause) {
	if(bPause)
		[videoPlayer pause];
	else {
		if([videoPlayer isPaused])
			[videoPlayer play];
	}
}

//protected ------------------------------

void ofiPhoneVideoPlayer::updateCurrentFrameRef() {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
    CVImageBufferRef imageBuffer = [videoPlayer getCurrentFrame]; 
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0); 
	
    /*Get information about the image*/
    uint8_t *baseAddress	= (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t bytesPerRow		= CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t widthIn			= CVPixelBufferGetWidth(imageBuffer); 
    size_t heightIn			= CVPixelBufferGetHeight(imageBuffer);  
	
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace	= CGColorSpaceCreateDeviceRGB(); 
    CGContextRef newContext		= CGBitmapContextCreate(baseAddress, widthIn, heightIn, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage			= CGBitmapContextCreateImage(newContext); 
	
	CGImageRelease(currentFrameRef);	
	currentFrameRef = CGImageCreateCopy(newImage);		
	
    /*We release some components*/
    CGContextRelease(newContext); 
    CGColorSpaceRelease(colorSpace);
	
	/*We relase the CGImageRef*/
	CGImageRelease(newImage);
	
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
	if(width==0 && widthIn != 0)
		pixels = new unsigned char[widthIn*heightIn*(bytesPerRow/widthIn)];
		
	width = widthIn;
	height = heightIn;
	[pool drain];
}

//----------------------------------------

void ofiPhoneVideoPlayer::initWithPath(string path) {
	videoPlayer = [[AVFoundationVideoGrabber alloc] initWithPath:ofxStringToNSString(ofToDataPath(path))];
	videoWasStopped=false;
}