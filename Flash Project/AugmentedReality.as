﻿package 
{

	//--------------------------------------
	//  Imports 这个版本可以2个dae一起显示，但会互换位置，甚至都集中到一个图形上
	//--------------------------------------
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.utils.ByteArray;

	import org.libspark.flartoolkit.core.FLARCode;
	import org.libspark.flartoolkit.core.param.FLARParam;
	import org.libspark.flartoolkit.core.raster.rgb.FLARRgbRaster_BitmapData;
	import org.libspark.flartoolkit.core.transmat.FLARTransMatResult;
	import org.libspark.flartoolkit.detector.FLARMultiMarkerDetector;
	import org.libspark.flartoolkit.pv3d.FLARBaseNode;
	import org.libspark.flartoolkit.pv3d.FLARCamera3D;

	import org.papervision3d.lights.PointLight3D;
	import org.papervision3d.materials.shadematerials.FlatShadeMaterial;
	import org.papervision3d.materials.utils.MaterialsList;
	import org.papervision3d.objects.parsers.DAE;
	import org.papervision3d.objects.primitives.Cube;
	import org.papervision3d.render.BasicRenderEngine;
	import org.papervision3d.render.LazyRenderEngine;
	import org.papervision3d.scenes.Scene3D;
	import org.papervision3d.view.Viewport3D;


	//--------------------------------------
	//  Class Definition
	//--------------------------------------
	public class AugmentedReality extends Sprite
	{

		//--------------------------------------
		//  Class Properties
		//--------------------------------------

		//1. WebCam
		private var video: Video;
		private var webcam: Camera;

		private var i:int;

		//2. FLAR Marker Detection
		private var flarBaseNode: FLARBaseNode;
		private var flarParam: FLARParam;
		private var flarCode: FLARCode;
		private var flarRgbRaster_BitmapData: FLARRgbRaster_BitmapData;
		private var flarSingleMarkerDetector: FLARMultiMarkerDetector;
		private var flarCamera3D: FLARCamera3D;
		private var flarTransMatResult: FLARTransMatResult;
		private var flarTransMatResult2: FLARTransMatResult;
		private var bitmapData: BitmapData;
		private var FLAR_CODE_SIZE: uint = 16;
		private var MARKER_WIDTH: uint = 80;

		private var flarSingleMarkerDetector2: FLARMultiMarkerDetector;
		private var flarCode2: FLARCode;
		private var flarBaseNode2: FLARBaseNode;

		[Embed(source = "./assets/FLAR/FLARPattern.pat",mimeType = "application/octet-stream")]
		private var Pattern: Class;

		[Embed(source = "./assets/FLAR/mikko.pat",mimeType = "application/octet-stream")]
		private var Pattern2:Class;

		[Embed(source = "./assets/FLAR/FLARCameraParameters.dat",mimeType = "application/octet-stream")]
		private var Params:Class;

		//3. PaperVision3D
		private var basicRenderEngine: BasicRenderEngine;
		private var basicRenderEngine2: BasicRenderEngine;
		private var lazyRenderEngine: LazyRenderEngine
		private var viewport3D: Viewport3D;
		private var scene3D: Scene3D;
		private var collada3DModel: DAE;

		private var scene3D2: Scene3D;
		private var collada3DModel2: DAE;
		private var codeArr:Array = [];
		private var nodeArr:Array = []
		private var sceneArr:Array = []
		private var enArr:Array = []
		private var resArr:Array = []
		
		private var markerId:int;
		
		//Fun, Editable Properties
		private var VIDEO_WIDTH : Number = 640;//Set 100 to 1000 to set width of screen
		private var VIDEO_HEIGHT : Number = 480;//Set 100 to 1000 to set height of screen
		private var WEB_CAMERA_WIDTH : Number = VIDEO_WIDTH/2;//Smaller than video runs faster
		private var WEB_CAMERA_HEIGHT : Number = VIDEO_HEIGHT/2;//Smaller than video runs faster
		private var VIDEO_FRAME_RATE : Number = 30;//Set 5 to 30.  Higher values = smoother video
		private var DETECTION_THRESHOLD: uint  = 80;//Set 50 to 100. Set to detect marker more accurately.
		private var DETECTION_CONFIDENCE: Number = 0.5;//Set 0.1 to 1. Set to detect marker more accurately.
		private var MODEL_SCALE : Number = 0.0175;//Set 0.01 to 5. Set higher to enlarge model

		//Fun, Editable Properties: Load a Different Model
		private var COLLADA_3D_MODEL : String = "./assets/models/tower/models/tower.dae";
		private var COLLADA_3D_MODEL2 : String = "./assets/models/tower/models/mobile.DAE";
		private var ce:CardEmulator;
		//--------------------------------------
		//  Constructor
		//--------------------------------------

		/**
		 * The constructor is the ideal place 
		 * for project setup since it only runs once.
		 * Prepare A,B, & C before repeatedly running D.
		**/
		public function AugmentedReality()
		{
			//Prepare
			//prepareWebCam();  //Step A
			ce = new CardEmulator("assets/models/tower/images/marker00.jpg","assets/models/tower/images/marker_v1.jpg",VIDEO_WIDTH,VIDEO_HEIGHT,true);
			addChild(ce);
			prepareMarkerDetection();//Step B
			preparePaperVision3D();//Step C

			//Repeatedly call the loop method
			//to detect and adjust the 3D model.
			addEventListener(Event.ENTER_FRAME, loopToDetectMarkerAndUpdate3D);//Step D
		}


		//--------------------------------------
		//  Methods
		//--------------------------------------

		/**
		 * A. Access the user's webcam, wire it 
		 *    to a video object, and display the
		 *    video onscreen.
		**/
		private function prepareWebCam():void
		{
			video = new Video(VIDEO_WIDTH,VIDEO_HEIGHT);
			webcam = Camera.getCamera();
			webcam.setMode(WEB_CAMERA_WIDTH, WEB_CAMERA_HEIGHT, VIDEO_FRAME_RATE);
			video.attachCamera(webcam);
			addChild(video);
		}


		/**
		 * B. Prepare the FLAR tools to detect with
		 *  parameters, the marker pattern, and
		 *  a BitmapData object to hold the information
		 *    of the most recent webcam still-frame.
		**/
		private function prepareMarkerDetection():void
		{
			//The parameters file corrects imperfections
			//In the webcam's image.  The pattern file
			//defines the marker graphic for detection
			//by the FLAR tools.
			flarParam = new FLARParam();
			flarParam.loadARParam(new Params() as ByteArray);
			flarCode = new FLARCode(FLAR_CODE_SIZE,FLAR_CODE_SIZE);
			flarCode.loadARPatt(new Pattern());

			flarCode2 = new FLARCode(FLAR_CODE_SIZE,FLAR_CODE_SIZE);
			flarCode2.loadARPatt(new Pattern2());

			codeArr=[flarCode,flarCode2];
			
			//A BitmapData is Flash's version of a JPG image in memory.
			//FLAR studies this image every frame with its
			//marker-detection code.
			bitmapData = new BitmapData(VIDEO_WIDTH,VIDEO_HEIGHT);
			bitmapData.draw(ce.viewport);
			/*bitmapData = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
			bitmapData.draw(video);*/
			flarRgbRaster_BitmapData = new FLARRgbRaster_BitmapData(bitmapData);
			flarSingleMarkerDetector = new FLARMultiMarkerDetector(flarParam,codeArr,[MARKER_WIDTH,MARKER_WIDTH],2);

			//flarSingleMarkerDetector2 = new FLARSingleMarkerDetector (flarParam, flarCode2, MARKER_WIDTH);
		}


		/**
		 * C. Create PaperVision3D's 3D tools including
		 *  a scene, a base node container to hold the
		 *  3D Model, and the loaded 3D model itself. 
		**/
		private function preparePaperVision3D():void
		{
			//Basics of the empty 3D scene fit for
			//FLAR detection inside a 3D render engine.
			basicRenderEngine = new BasicRenderEngine();
			basicRenderEngine2 = new BasicRenderEngine();
			enArr = [basicRenderEngine,basicRenderEngine2]
			
			//lazyRenderEngine=new LazyRenderEngine
			
			flarTransMatResult = new FLARTransMatResult();
			flarTransMatResult2 = new FLARTransMatResult();
			resArr = [flarTransMatResult,flarTransMatResult2]
			viewport3D = new Viewport3D();
			flarCamera3D = new FLARCamera3D(flarParam);
			flarBaseNode = new FLARBaseNode();
			scene3D = new Scene3D();
			scene3D.addChild(flarBaseNode);

			flarBaseNode2 = new FLARBaseNode();
			scene3D2 = new Scene3D();
			scene3D2.addChild(flarBaseNode2);
			scene3D.addChild(flarBaseNode2);
			
			nodeArr = [flarBaseNode,flarBaseNode2]
		sceneArr = [scene3D,scene3D2]

			//Load, scale, and position the model
			//The position and rotation will be
			//adjusted later in method D below.
			collada3DModel = new DAE ();
			collada3DModel.load(COLLADA_3D_MODEL);
			collada3DModel.scaleX = collada3DModel.scaleY = collada3DModel.scaleZ = MODEL_SCALE;
			//collada3DModel.z = 5;//Moves Model 'Up' a Line Perpendicular to Marker
			collada3DModel.rotationX = 90;//Rotates Model Around 2D X-Axis of Marker
			collada3DModel.rotationY = 0;//Rotates Model Around 2D Y-Axis of Marker
			collada3DModel.rotationZ = 45;//Rotates Model Around a Line Perpendicular to Marker

			collada3DModel2 = new DAE ();
			collada3DModel2.load(COLLADA_3D_MODEL2);
			collada3DModel2.scaleX = collada3DModel2.scaleY = collada3DModel2.scaleZ = .5;
			//collada3DModel.z = 5;//Moves Model 'Up' a Line Perpendicular to Marker
			collada3DModel2.rotationX = 90;  //Rotates Model Around 2D X-Axis of Marker
			collada3DModel2.rotationY = 0;   //Rotates Model Around 2D Y-Axis of Marker
			collada3DModel2.rotationZ = 45;

			//Add the 3D model into the 
			//FLAR container and add the 
			//3D cameras view to the screen
			//so the user can view the result
			flarBaseNode.addChild(collada3DModel);
			flarBaseNode2.addChild(collada3DModel2);
			addChild(viewport3D);
			
			lazyRenderEngine = new LazyRenderEngine(scene3D,flarCamera3D,viewport3D);
		}


		/**
		 * D. Detect the marker in the webcamera. If
		 *  found: move, scale, and rotate the 
		 *  3D model to composite it over the marker
		 *  in the user's physical space.
		**/
		private function loopToDetectMarkerAndUpdate3D(aEvent : Event):void
		{

			//Copy the latest still-frame of the webcam video
			//into the BitmapData object for detection
			ce.render();
			bitmapData.draw(ce.viewport);
			try
			{

				//Detect *IF* the marker is found in the latest still-frame
				/*if(flarSingleMarkerDetector.detectMarkerLite (flarRgbRaster_BitmapData, DETECTION_THRESHOLD) && 
				flarSingleMarkerDetector.getConfidence() > DETECTION_CONFIDENCE) {
				trace("00000000")
				//Repeatedly Loop and Adjust 3D Model to Match Marker
				flarSingleMarkerDetector.getTransformMatrix(i,flarTransMatResult);
				flarBaseNode.setTransformMatrix(flarTransMatResult);
				basicRenderEngine.renderScene(scene3D, flarCamera3D, viewport3D);
				}*/
				for (i = 0; i< 2; i++)
				{
					if (flarSingleMarkerDetector.detectMarkerLite (flarRgbRaster_BitmapData, DETECTION_THRESHOLD) && 
					flarSingleMarkerDetector.getConfidence(i) > DETECTION_CONFIDENCE)
					{
						//trace(enArr[i]);
						//Repeatedly Loop and Adjust 3D Model to Match Marker
						markerId = flarSingleMarkerDetector.getARCodeIndex(i);
						flarSingleMarkerDetector.getTransmationMatrix(i,resArr[markerId]);
						nodeArr[i].setTransformMatrix(resArr[i]);
						//basicRenderEngine.renderScene(scene3D, flarCamera3D, viewport3D);
						lazyRenderEngine.render();
					}
				}
				/*if(flarSingleMarkerDetector2.detectMarkerLite (flarRgbRaster_BitmapData, DETECTION_THRESHOLD) && 
				flarSingleMarkerDetector2.getConfidence() > DETECTION_CONFIDENCE) {
				trace("1111111")
				//Repeatedly Loop and Adjust 3D Model to Match Marker
				flarSingleMarkerDetector2.getTransformMatrix(flarTransMatResult);
				flarBaseNode2.setTransformMatrix(flarTransMatResult);
				basicRenderEngine.renderScene(scene3D2, flarCamera3D, viewport3D);
				}*/
			}
			catch (error:Error)
			{
				trace(error.message+"364545645");
			}
		}
	}
}