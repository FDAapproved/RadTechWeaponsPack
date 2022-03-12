
//damage would be balefire, electro, radioactivity or heat/immolation
//missiletype, missileheight: tail used in A_FBTail()
//activesound: looping sound

class HDSwampyFlare:HDActor
{
	vector3 oldvel;
	vector3 frac;
	double fracc;
	double seekspeed;
	double zat;
	double grav;
	int firefatigue;
	bool impacted;
	property firefatigue:firefatigue;
	default{
		+notelestomp
		+missile +seekermissile +noblockmap +dropoff +activateimpact +activatepcross +hittracer
		+forcexybillboard +rollsprite +rollcenter +bright

		renderstyle "add";
		radius 4;height 4;speed 12;gravity 0.05;deathheight 30;
		missileheight 0;
		damagetype "hot";damagefunction(1);

		seesound "imp/attack";deathsound "imp/shotx";
		activesound "misc/firecrkl";
	}
	override void postbeginplay(){
		super.postbeginplay();
		skypos=(35000,35000,35000);
		seekspeed=speed*0.2;
		grav=getgravity();
		fracc=speed/radius;
		frac=vel/fracc;
		A_StartSound(seesound,CHAN_VOICE);
		A_StartSound(activesound,CHAN_BODY,volume:0.4,attenuation:4.);
		corkscrew=0;
		if(firefatigue){
			let hdmb=hdmobbase(target);
			if(hdmb){
				hdmb.firefatigue+=firefatigue;

				//reduce fireball speed if overexerting
				double hdmbf=hdmb.firefatigue-HDCONST_MAXFIREFATIGUE;
				if(hdmbf>0){
					double mlt=max(0.2,((HDCONST_MAXFIREFATIGUE-hdmbf)*(1./HDCONST_MAXFIREFATIGUE)));
					speed*=mlt;
					seekspeed*=mlt;
					vel*=mlt;
				}
			}
		}
	}
	bool A_FBSeek(
		int seekradius=256,
		bool inlosonly=true
	){
		if(!tracer)return false;
		vector3 totracer=(0,0,0.01);
		if(pos.z>tracer.pos.z+tracer.height*0.6)totracer.z=0;
			else totracer.z=tracer.height*0.6;
		totracer+=tracer.pos-self.pos;
		double disttotracer=distance3d(tracer);
		if(
			(!inlosonly||checksight(tracer))
			&&
			(disttotracer<seekradius)
		){
			vel+=totracer.unit()*seekspeed;
			return true;
		}
		return false;
	}
	void A_FBFloat(
		double jitter=0.02
	){
		if(jitter){
			jitter*=radius;
			vel+=(
				frandom(-jitter,jitter),
				frandom(-jitter,jitter),
				frandom(-jitter,jitter)
			);
		}
		zat=pos.z-floorz;
		if(zat<deathheight&&vel.z<0)vel.z+=(deathheight-zat)*0.06;
	}
	void A_FBTail(){
		if(!missilename) return;
		actor a=spawn(missilename,pos,ALLOW_REPLACE);
		a.master=self;a.vel=self.vel*0.9;
	}
	int corkscrew;
	vector3 skypos;
	void A_Corkscrew(double turnspeed=1.,bool clockwise=false,int adjustdegree=45){
		if(!corkscrew)turnspeed*=0.5;
		vector2 turnamt=angletovector(clockwise?corkscrew:-corkscrew,turnspeed);
		A_ChangeVelocity(sin(pitch)*turnamt.y,turnamt.x,cos(pitch)*turnamt.y,CVF_RELATIVE);
		corkscrew+=adjustdegree;if(corkscrew>720)corkscrew-=360;
	}
	override void Tick(){
		if(isfrozen()){
			clearinterpolation();
			return;
		}

		if(skypos!=(35000,35000,35000)){
			if(
				abs(skypos.x)>32000
				||abs(skypos.y)>32000
				||abs(skypos.z)>32000
			){
				destroy();
				return;
			}

			binvisible=true;
			skypos+=vel;
			setorigin(skypos,false);
			double topz=ceilingz-height;
			setz(clamp(pos.z,floorz,topz));

			if(skypos.z<topz){
				if(
					ceilingpic==skyflatnum
				){
					skypos=(35000,35000,35000);
					binvisible=false;
				}else{
					destroy();
					return;
				}
			}

			let ggg=getgravity();
			if(ggg>0){
				if(vel.z>-abs(default.speed*3))vel.z-=getgravity();
			}else destroy();
			return;
		}

		if(!bmissile){
			//I don't anticipate any use other than death state...
			trymove(pos.xy+vel.xy,true);
			if(pos.z<floorz)setz(floorz);
			else if(pos.z+height>ceilingz)setz(ceilingz-height);
			else addz(vel.z,true);
			vel*=0.9;

			NextTic();
			return;
		}
		if(vel.xy==(0,0))A_Recoil(-0.001);

		//prevent endless suicide orbits
		if(
			tracer==target
			&&getage()>(TICRATE*3)
		)bhitowner=true;

		//update frac
		if(oldvel!=vel){
			oldvel=vel;
			fracc=max(vel.xy.length()/radius,1);
			frac=vel/fracc;
		}

		//the iterator
		for(int i=0;i<fracc;i++){
			fcheckposition tm;

			//hit something while moving horizontally
			if(!trymove(pos.xy+frac.xy,true,true,tm)){
				if(!bSkyExplode){
					let l=tm.ceilingline;
					let p=tm.ceilingpic;
					if(l&&l.backsector){
						if(
							ceilingpic==skyflatnum
							&&tm.ceilingpic==skyflatnum
							&&tm.pos.z>=tm.ceilingz
						){
							destroy();
							return;
						}
					}
				}
				if(!target)target=master;
				explodemissile(BlockingLine,BlockingMobj);
				return;
			}

 // no more vanishing in skies, i hope

		//	if(blockingline&&blockingline.special==Line_Horizon){
		//		destroy();
		//		return;
		//	}

			CheckPortalTransition();
			addz(frac.z,true);

			//check skyfloor first before usual
			if(
				!bSkyExplode
				&& floorpic==skyflatnum
				&& pos.z<floorz
			){
		//destroy();
				return;
			}else if(pos.z<floorz){
				setz(floorz);
				hitfloor();
				explodemissile(null,null);
				return;
			}

			//by the time it comes back down it would have dissipated!
			//(this rationalization is subject to change)
			if(
				!bSkyExplode
				&&ceilingpic==skyflatnum
				&&pos.z+height>ceilingz
			){
				if(getgravity()>0){
					skypos=pos;
				}else	return;
			}else if(pos.z+height>ceilingz){
				setz(ceilingz-height);
				explodemissile(null,null);
				return;
			}
		}
		if(grav)vel.z-=grav;

		NextTic();
	}
}
//end of HDSwampyFlare




class HDFlareBall:HDSwampyFlare{

	int iii_max;
	int iii_inc;
	int iii;
	int frametick;
	
	double initangleto;
	double inittangle;
	double inittz;
	vector3 initpos;
	vector3 initvel;
	default
	{
		+bright
		missiletype "HDImpBallTail";
		decal "BrontoScorch";
		speed 32;
		damagetype "electrical";
		gravity 0;
		scale 0.25;
		hdswampyflare.firefatigue int(HDCONST_MAXFIREFATIGUE*0.2);
	}


	override void Tick()
	{
		if(isfrozen()){
			clearinterpolation();
			return;
		}
		Super.Tick();
	}


	virtual void A_HDIBFly(){
		roll+=10;
		if(
			!(getage()&(1|2))
			||!A_FBSeek()
		){
			vel*=0.99;
			A_FBFloat();
			A_Corkscrew(stamina*frandom(0,0.4));if(stamina<5)stamina++;
		}
	}

action void A_SpawnSparks()
{

	actor sp=spawn("HDFlameRed",pos,ALLOW_REPLACE);
	sp.vel+=target.vel+(frandom(-2,2), frandom(-2,2), frandom(-1,3));
	A_StartSound("misc/firecrkl", CHAN_BODY, CHANF_OVERLAP, volume:0.4, attenuation:6.);

}

action void A_Crackle(int tic, int ticktocrackle, double cracklevolume)
{		
		if(!(tic%ticktocrackle))
			A_StartSound("flaregun/flareburn", CHAN_BODY, CHANF_OVERLAP, volume:cracklevolume);
}


// Technically not an action script. 
void A_BurnUp(int tic, int crackletime, int sparktime, int damagetime, int frameoffset,
bool shoulddamage=true)
{
	// Noise and visuals. 
	A_Crackle(tic, crackletime, 1);
	if(!(tic%sparktime))
		{

			A_SpawnSparks();
			frametick = (frametick + 1) % 3;
			frame = frameoffset + frametick;
		}
	
	
	// Whether or not to damage. 
	if(!(tic%damagetime) && shoulddamage)
	{
		A_ImpSquirt();
	}
	else
		A_ImpNoSquirt();
}

	
void A_ImpSquirt(){
		roll=frandom(0,360);
		if(!tracer)return;

		double diff=max(
			absangle(initangleto,angleto(tracer)),
			absangle(inittangle,tracer.angle),
			abs(inittz-tracer.pos.z)*0.05
		);

		int dmg=int(max(0,10-diff*0.1));

		if(
			tracer.bismonster
			&&!tracer.bnopain
			&&tracer.health>0
		)tracer.angle+=randompick(-1,1);

		//do it again
		initangleto=angleto(tracer);
		inittangle=tracer.angle;
		inittz=tracer.pos.z;

		setorigin((pos+(tracer.pos-initpos))*0.5,true);

		if(dmg){
			tracer.A_GiveInventory("Heat",dmg);

			tracer.damagemobj(self,target,max(1,dmg>>5),"hot");
                                            //default is 2
		}

actor sp=spawn("HDFlameRed",pos,ALLOW_REPLACE);
		sp.vel+=target.vel+(frandom(-2,2), frandom(-2,2), frandom(-1,3));
		A_StartSound("misc/firecrkl", CHAN_BODY, CHANF_OVERLAP, volume:0.4, attenuation:6.);


	}

void A_ImpNoSquirt(){
		roll=frandom(0,360);
		if(!tracer)return;

		
		double diff=max(
			absangle(initangleto,angleto(tracer)),
			absangle(inittangle,tracer.angle),
			abs(inittz-tracer.pos.z)*0.05
		);

		int dmg=int(max(0,10-diff*0.1));

		if(
			tracer.bismonster
			&&!tracer.bnopain
			&&tracer.health>0
		)tracer.angle+=randompick(-1,1);

		//do it again
		initangleto=angleto(tracer);
		inittangle=tracer.angle;
		inittz=tracer.pos.z;

		
		//setorigin(pos+tracer.pos-initpos*0.5,true);
		vector3 newposition;
		newposition = tracer.pos;
		newposition.z = tracer.height * 0.82;
		setorigin(newposition,true);
	}
	

	override void postbeginplay(){
		super.postbeginplay();
		impacted = false;
		if(vel.x||vel.y||vel.z)initvel=vel.unit();
		else{
			double cp=cos(pitch);
			initvel=(cp*cos(angle),cp*sin(angle),-sin(pitch));
		}
		initvel*=0.3;
	}
	void A_FBTailAccelerate(){
		A_FBTail();
		vel+=initvel;
	}
	states{
	spawn:
//bright light, bright light!
		HL1G ABABABABAB 2 bright light("FLARESHOTLIGHTFADE") A_FBTailAccelerate();
	spawn2:
		HL1G AB 3 bright light("FLARESHOTLIGHTFADE") A_HDIBFly();
		loop;
	Death:
		TNT1 AAA 0 A_SpawnItemEx("HDSmoke",flags:SXF_NOCHECKPOSITION);
		TNT1 A 0
		{
			A_Scream();
			tracer=null;
			if(blockingmobj){
				if(blockingmobj is "Serpentipede"&&(!target||blockingmobj!=target.target))
				{
					blockingmobj.givebody(random(1,5));
					impacted = true;
					return;
				}
				else
				{
					tracer=blockingmobj;
					
					// HOTHOTHOT
					blockingmobj.damagemobj(self,target,random(5,6),"electrical");
					blockingmobj.damagemobj(self,target,random(4,5),"thermal");
					A_Immolate(blockingmobj,master,40);
					invoker.destroy();
					impacted = true;
					return;
				}
			}
			if(tracer){
				initangleto=angleto(tracer);
				inittangle=tracer.angle;
				inittz=tracer.pos.z;
				initpos=tracer.pos-pos;

				let hdt=hdmobbase(tracer);

				//HEAD SHOT
				if(
					pos.z-tracer.pos.z>tracer.height*0.8
					&&(
						!hdt
						||(
							!hdt.bnovitalshots
							&&!hdt.bheadless
						)
					)
				){
					if(hd_debug)A_Log("HEAD SHOT");
					bpiercearmor=false;
				}
			}
		}
	TNT1 A 0
	{
			if(impacted)setstatelabel("DeathInitInvisible");
	}
	DeathInit:
		  HL1G E 0
		  {
			iii_max    = random(100,105) * 35;
			iii_inc    = iii_max/3;
			iii        = 0;
			frametick  = 0;
		  }
	DeathFlamesStrong:
		  HL1G D 1 light("FLARESHOTLIGHT")
		  {
			A_BurnUp(iii, 4, 4, 20, 0);
			iii++;
		  }
		  TNT1 A 0 A_JumpIf(iii < iii_max - (iii_inc * 2), "DeathFlamesStrong");
		  TNT1 A 0 {scale *= 0.95;}
	DeathFlames:
		  HL1G D 2 light("FLARESHOTLIGHT")
		  {
			A_BurnUp(iii, 5, 5, 30, 1);
			iii++;
		  }
		  TNT1 A 0 A_JumpIf(iii < iii_max - iii_inc, "DeathFlames");
		  TNT1 A 0 {scale *= 0.80;}
	DeathFlamesDying:
		  HL1G E 3 light("FLARESHOTLIGHTDYING")
		  {
			A_BurnUp(iii, 6, 6, 50, 1);
			iii++;
		  }
		  TNT1 A 0 A_JumpIf(iii < iii_max, "DeathFlamesDying");
		  stop;	
	
	
	
	// Frames for when a flare hits an enemy (gives some light). 
	DeathInitInvisible:
		  TNT1 A 0
		  {
			iii_max    = random(5,8) * 35;
			iii_inc    = iii_max/3;
			iii        = 0;
			frametick  = 0;
		  }
	DeathFlamesStrongInvisible:
		  TNT1 A 1 light("FLARESHOTLIGHT")
		  {
			A_BurnUp(iii, 4, 4, 20, 0, false);
			iii++;
		  }
		  TNT1 A 0 A_JumpIf(iii < iii_max - (iii_inc * 2), "DeathFlamesStrongInvisible");
		  TNT1 A 0 {scale *= 0.95;}
	DeathFlamesInvisible:
		  TNT1 A 2 light("FLARESHOTLIGHT")
		  {
			A_BurnUp(iii, 5, 5, 30, 1, false);
			iii++;
		  }
		  TNT1 A 0 A_JumpIf(iii < iii_max - iii_inc, "DeathFlamesInvisible");
		  TNT1 A 0 {scale *= 0.80;}
	DeathFlamesDyingInvisible:
		  TNT1 A 3 light("FLARESHOTLIGHTDYING")
		  {
			A_BurnUp(iii, 6, 6, 50, 1, false);
			iii++;
		  }
		  TNT1 A 0 A_JumpIf(iii < iii_max, "DeathFlamesDyingInvisible");
		  stop;
		}
}