
import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, SCNPhysicsContactDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var piratesLabel: UILabel!
    @IBOutlet weak var bombsLabel: UILabel!
    @IBOutlet weak var HealthBar: UIStackView!
    
    let sceneManager = ARSceneManager()
    let pirateSpawnSound = SCNAudioSource(named: "pirate_spawn.wav")
    let pirateDeathSound = SCNAudioSource(named: "pirate_death.wav")
    let bulletFiredSound = SCNAudioSource(named: "bullet_fired.wav")
    let bulletHitSound = SCNAudioSource(named: "bullet_hit.wav")
    let bombFiredSound = SCNAudioSource(named: "bomb_fired.wav")
    let bombHitSound = SCNAudioSource(named: "bomb_hit.mp3")
    let civilianSpawnSound = SCNAudioSource(named: "civilian_spawn.wav")
    let civilianSavedSound = SCNAudioSource(named: "civilian_saved.mp3")
    let civilianDeathSound = SCNAudioSource(named: "civilian_death.mp3")
    let bossSpawnSound = SCNAudioSource(named: "boss_spawn.wav")
    let bossDeathSound = SCNAudioSource(named: "boss_death.wav")

    let degreesToRadians = CGFloat.pi / 180
    let radiansToDegrees = 180 / CGFloat.pi
    let pirateArmySize = 20
    let civilianAppearanceRate = 5

    var playerNode = SCNNode()
    var playerHealth = 5
    var piratesShot = 0
    var piratesCreated = 0
    var bombCount = 5
    var timers = [Timer]()
    var targets = [SCNNode]()
    var isGameActive = false
    var isCivilianActive = false
    var isBossActive = false
    var isBossDefeated = false
    var bossHealth = 20

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneManager.attach(to: sceneView)

        /*
         Prevent the screen from being dimmed after a while as users will likely
         have long periods of interaction without touching the screen or buttons.
         */
        UIApplication.shared.isIdleTimerDisabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapScene(_:)))
        view.addGestureRecognizer(tapGesture)

//                sceneManager.displayDegubInfo()
        
        let box = SCNBox(width: 0.025, height: 0.04, length: 0.01, chamferRadius: 0.0)
        //        let box = SCNBox(width: 0.5, height: 1, length: 0.5, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1)
        playerNode = SCNNode(geometry: box)
        let orientation = SCNVector3(x: 0, y: 0, z: 0.011)
        playerNode.position = orientation
        let physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: box, options: nil))
        playerNode.physicsBody = physicsBody
        playerNode.physicsBody?.categoryBitMask = CollisionCategory.player.rawValue
        playerNode.physicsBody?.contactTestBitMask = CollisionCategory.enemyShot.rawValue
        //        playerNode.physicsBody?.collisionBitMask = CollisionCategory.player.rawValue
        sceneView.pointOfView?.addChildNode(playerNode)
        print("Placing player hitbox at \(playerNode.worldPosition.x),\(playerNode.worldPosition.y),\(playerNode.worldPosition.z)")
    }

    func startNewGame() {
        for timer in timers {
            timer.invalidate()
        }

        isGameActive = true
        playerHealth = 5
        piratesShot = 0
        piratesCreated = 0
        bombCount = 5

        pirateSpawnSound?.load()
        pirateDeathSound?.load()
        bulletFiredSound?.load()
        bulletHitSound?.load()
        bombFiredSound?.load()
        bombHitSound?.load()
        civilianSpawnSound?.load()
        civilianSavedSound?.load()
        civilianDeathSound?.load()
        bossSpawnSound?.load()
        bossDeathSound?.load()
        updatePlayerHealthMeter()

        piratesLabel.text = "Pirates Shot: \(piratesShot)/\(piratesCreated)"
        bombsLabel.text = "Cannonballs: \(bombCount)"
    }

    @objc func didTapScene(_ gesture: UITapGestureRecognizer) {
        switch gesture.state {
        case .ended:
            let location = gesture.location(ofTouch: 0,
                                            in: sceneView)
            guard let result = sceneView.hitTest(location, options: nil).first else { return }
            if result.node.physicsBody?.categoryBitMask == CollisionCategory.civilian.rawValue && isGameActive {
                if playerHealth < 5 {
                    playerHealth += 1
                    updatePlayerHealthMeter()
                }
                bombCount += 1
                bombsLabel.text = "Cannonballs: \(bombCount)"

                playerNode.runAction(SCNAction.playAudio(civilianSavedSound!, waitForCompletion: false))
                let sequence = SCNAction.sequence([SCNAction.fadeOut(duration: 1.0),
                                                   SCNAction.removeFromParentNode()])
                result.node.runAction(sequence)
                isCivilianActive = false
            }
        default:
            print("tapped default")
        }
    }

    func createCivilian() {
        let planeCount = sceneManager.getPlanes().count
        let randomizer = Int(arc4random_uniform(UInt32(planeCount)))
        let plane = sceneManager.getPlanes()[randomizer]
        let minPlaneCorner = plane.boundingBox.min
        let maxPlaneCorner = plane.boundingBox.max

        let randomX = randomFloatBetween(minPlaneCorner.x+0.015, and: maxPlaneCorner.x-0.015)
        let randomZ = randomFloatBetween(minPlaneCorner.z+0.015, and: maxPlaneCorner.z-0.015)

        let civilianPlane = SCNPlane(width: 0.03, height: 0.06)
        let civilian = SCNNode(geometry: civilianPlane)

        civilian.geometry?.firstMaterial = createMaterialFromImage(named: "sprinkles")
        civilian.geometry?.firstMaterial?.isDoubleSided = true

        civilian.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: civilianPlane, options: nil))
        civilian.physicsBody?.categoryBitMask = CollisionCategory.civilian.rawValue
        civilian.physicsBody?.collisionBitMask = CollisionCategory.civilian.rawValue
        civilian.physicsBody?.contactTestBitMask = CollisionCategory.bullet.rawValue | CollisionCategory.bomb.rawValue
        civilian.position = SCNVector3Make(randomX, 0.03, randomZ)
        isCivilianActive = true

        let yFreeConstraint = SCNBillboardConstraint()
        yFreeConstraint.freeAxes = .Y
        civilian.constraints = [yFreeConstraint]

        plane.addChildNode(civilian)
        playerNode.runAction(SCNAction.playAudio(civilianSpawnSound!, waitForCompletion: false))
    }

    func createRandomTarget() {
        let planeCount = sceneManager.getPlanes().count
        let randomizer = Int(arc4random_uniform(UInt32(planeCount)))
        let plane = sceneManager.getPlanes()[randomizer]
        let minPlaneCorner = plane.boundingBox.min
        let maxPlaneCorner = plane.boundingBox.max
        
        let randomX = randomFloatBetween(minPlaneCorner.x+0.015, and: maxPlaneCorner.x-0.015)
        let randomZ = randomFloatBetween(minPlaneCorner.z+0.015, and: maxPlaneCorner.z-0.015)
//        print("Create random target at \(randomX),\(randomZ), between \(plane.boundingBox.min),\(plane.boundingBox.max)")

        let enemy = EnemyTarget()
        enemy.position = SCNVector3Make(randomX, 0.0, randomZ)

        targets.append(enemy)
        plane.addChildNode(enemy)
        enemy.runAction(SCNAction.playAudio(pirateSpawnSound!, waitForCompletion: false))
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true, block: {timer in
            if enemy.isAlive {
                self.enemyFires(enemy: enemy, deviation: 0.05, bulletSpeed: 1.0)
            } else {
                timer.invalidate()
            }
        })
        timers.append(timer)
        piratesCreated += 1
        DispatchQueue.main.async {
            self.piratesLabel.text = "Pirates Shot: \(self.piratesShot)/\(self.piratesCreated)"
        }
    }

    func createBoss() {
        isBossActive = true

        let planeCount = sceneManager.getPlanes().count
        let randomizer = Int(arc4random_uniform(UInt32(planeCount)))
        let plane = sceneManager.getPlanes()[randomizer]
        let minPlaneCorner = plane.boundingBox.min
        let maxPlaneCorner = plane.boundingBox.max

        let randomX = randomFloatBetween(minPlaneCorner.x+0.015, and: maxPlaneCorner.x-0.015)
        let randomZ = randomFloatBetween(minPlaneCorner.z+0.015, and: maxPlaneCorner.z-0.015)

        let bossPlane = SCNPlane(width: 0.035, height: 0.07)
        let boss = SCNNode(geometry: bossPlane)

        boss.geometry?.firstMaterial = createMaterialFromImage(named: "ugly_mug")
        boss.geometry?.firstMaterial?.isDoubleSided = true
        
        boss.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: bossPlane, options: nil))
        boss.physicsBody?.categoryBitMask = CollisionCategory.boss.rawValue
        boss.physicsBody?.collisionBitMask = CollisionCategory.boss.rawValue
        boss.physicsBody?.contactTestBitMask = CollisionCategory.bullet.rawValue | CollisionCategory.bomb.rawValue
        boss.position = SCNVector3Make(randomX, 0.03, randomZ)
        
        let yFreeConstraint = SCNBillboardConstraint()
        yFreeConstraint.freeAxes = .Y
        boss.constraints = [yFreeConstraint]

        plane.addChildNode(boss)
        playerNode.runAction(SCNAction.playAudio(bossSpawnSound!, waitForCompletion: false))

        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: {timer in
            if self.bossHealth > 0 {
                self.enemyFires(enemy: boss, deviation: 0.0, bulletSpeed: 1.5)
            } else {
                timer.invalidate()
            }
        })
        timers.append(timer)
    }

    func createVictoryScene(position: SCNVector3) {
        let planeCount = sceneManager.getPlanes().count
        let randomizer = Int(arc4random_uniform(UInt32(planeCount)))
        let plane = sceneManager.getPlanes()[randomizer]
        
        let victoryPlane = SCNPlane(width: 0.187, height: 0.15)
        let victoryScene = SCNNode(geometry: victoryPlane)
        
        victoryScene.geometry?.firstMaterial = createMaterialFromImage(named: "victory")
        victoryScene.geometry?.firstMaterial?.isDoubleSided = true
        
        victoryScene.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: victoryPlane, options: nil))
        victoryScene.position = SCNVector3Make(position.x, 0.075, position.z)

        let yFreeConstraint = SCNBillboardConstraint()
        yFreeConstraint.freeAxes = .Y
        victoryScene.constraints = [yFreeConstraint]
        
        plane.addChildNode(victoryScene)
        playerNode.runAction(SCNAction.playAudio(civilianSavedSound!, waitForCompletion: false))
    }

    func randomFloatBetween(_ min: Float, and max: Float) -> Float {
        return (Float(arc4random()) / Float(UInt32.max)) * (max - min) + min
    }

//    func session(_ session: ARSession, didUpdate frame: ARFrame) {
//        guard let cameraTransform = session.currentFrame?.camera.transform else { return }
//        let cameraPosition = SCNVector3(
//            // At this moment you could be sure, that camera properly oriented in world coordinates
//            cameraTransform.columns.3.x,
//            cameraTransform.columns.3.y,
//            cameraTransform.columns.3.z
//        )
//
//        // Now you have cameraPosition with x,y,z coordinates and you can calculate distance between those to points
//        let randomPoint = CGPoint(
//            // Here you can make random point for hitTest
//            x: CGFloat(arc4random()) / CGFloat(UInt32.max),
//            y: CGFloat(arc4random()) / CGFloat(UInt32.max)
//        )
//
//        guard let testResult = frame.hitTest(randomPoint, types: .featurePoint).first else { return }
//        let objectPoint = SCNVector3(
//            // Converting 4x4 matrix into x,y,z point
//            testResult.worldTransform.columns.3.x,
//            testResult.worldTransform.columns.3.y,
//            testResult.worldTransform.columns.3.z
//        )
//    }

    func placeTargetAt(_ point: CGPoint) {
        let target = EnemyTarget()
        sceneView?.scene.rootNode.addChildNode(target)
    }

    func placeBlockOnPlaneAt(_ hit: ARHitTestResult) {
        let target = EnemyTarget()
        position(node: target, atHit: hit)
        
        sceneView?.scene.rootNode.addChildNode(target)
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.bullet.rawValue && contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.target.rawValue {
            hitTarget(bullet: contact.nodeA, target: contact.nodeB as! EnemyTarget, isBomb: false)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.target.rawValue && contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.bullet.rawValue {
            hitTarget(bullet: contact.nodeB, target: contact.nodeA as! EnemyTarget, isBomb: false)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.bomb.rawValue && contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.target.rawValue {
            hitTarget(bullet: contact.nodeA, target: contact.nodeB as! EnemyTarget, isBomb: true)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.target.rawValue && contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.bomb.rawValue {
            hitTarget(bullet: contact.nodeB, target: contact.nodeA as! EnemyTarget, isBomb: true)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.enemyShot.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.player.rawValue {
            hitPlayer(bullet: contact.nodeA, player: contact.nodeB)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.player.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.enemyShot.rawValue {
            hitPlayer(bullet: contact.nodeB, player: contact.nodeA)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.bullet.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.civilian.rawValue {
            hitCivilian(bullet: contact.nodeA, civilian: contact.nodeB)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.civilian.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.bullet.rawValue {
            hitCivilian(bullet: contact.nodeB, civilian: contact.nodeA)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.bullet.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.boss.rawValue {
            hitBoss(bullet: contact.nodeA, boss: contact.nodeB)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.boss.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.bullet.rawValue {
            hitBoss(bullet: contact.nodeB, boss: contact.nodeA)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.bomb.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.boss.rawValue {
            hitBoss(bullet: contact.nodeA, boss: contact.nodeB)
        } else if contact.nodeA.physicsBody?.categoryBitMask == CollisionCategory.boss.rawValue &&
            contact.nodeB.physicsBody?.categoryBitMask == CollisionCategory.bomb.rawValue {
            hitBoss(bullet: contact.nodeB, boss: contact.nodeA)
        }
    }

    func hitBoss(bullet: SCNNode, boss: SCNNode) {
        if bullet.isKind(of: Projectile.self) {
            bullet.removeFromParentNode()
        }
        boss.runAction(SCNAction.playAudio(bulletHitSound!, waitForCompletion: false))

        if bossHealth > 0 {
            bossHealth -= 1
        }

        if bossHealth <= 0 {
            isGameActive = false
            isBossDefeated = true
            isBossActive = false
            let bossPosition = boss.position
            let deathSequence = SCNAction.sequence([SCNAction.fadeOut(duration: 1.0),
                                                    SCNAction.removeFromParentNode()])
            playerNode.runAction(SCNAction.playAudio(bossDeathSound!, waitForCompletion: false))
            boss.runAction(deathSequence)
            createVictoryScene(position: bossPosition)
        }
    }

    func hitCivilian(bullet: SCNNode, civilian: SCNNode) {
        isCivilianActive = false
        civilian.physicsBody?.categoryBitMask = CollisionCategory.none.rawValue
        if bullet.isKind(of: Projectile.self) {
            bullet.removeFromParentNode()
        }
        civilian.runAction(SCNAction.playAudio(bulletHitSound!, waitForCompletion: false))

        let deathSequence = SCNAction.sequence([SCNAction.fadeOut(duration: 1.0),
                                                SCNAction.removeFromParentNode()])
        playerNode.runAction(SCNAction.playAudio(civilianDeathSound!, waitForCompletion: false))
        civilian.runAction(deathSequence)
        
        if playerHealth > 0 {
            playerHealth -= 1
            DispatchQueue.main.async {
                self.updatePlayerHealthMeter()
            }
        }
    }

    func hitPlayer(bullet: SCNNode, player: SCNNode) {
        bullet.removeFromParentNode()
        playerNode.runAction(SCNAction.playAudio(bulletHitSound!, waitForCompletion: false))
        if playerHealth > 0 {
            playerHealth -= 1
            DispatchQueue.main.async {
                self.updatePlayerHealthMeter()
            }
        }
    }

    func updatePlayerHealthMeter() {
        for view in HealthBar.subviews {
            view.removeFromSuperview()
        }
        for i in 1...5 {
            if i <= playerHealth {
                HealthBar.addArrangedSubview(UIImageView(image: UIImage(named: "heart_full")))
            } else {
                HealthBar.addArrangedSubview(UIImageView(image: UIImage(named: "heart_empty")))
            }
        }
        if playerHealth <= 0 {
            displayGameEndMessage(title: "Game Over!", message: "You ran out of health!")
        }
    }

    func displayGameEndMessage(title: String, message: String) {
        isGameActive = false
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    func hitTarget(bullet: SCNNode, target: EnemyTarget, isBomb: Bool) {
        target.isAlive = false
        target.physicsBody?.categoryBitMask = CollisionCategory.none.rawValue
        if bullet.isKind(of: Projectile.self) {
            bullet.removeFromParentNode()
        }

        let rotate90 = CGFloat(Float.pi / 2.0)
        let fallInDirection = [SCNAction.rotateBy(x: 0, y: 0, z: -rotate90, duration: 0.3),
                             SCNAction.rotateBy(x: 0, y: 0, z: rotate90, duration: 0.3),
                             SCNAction.rotateBy(x: rotate90, y: 0, z: 0, duration: 0.3),
                             SCNAction.rotateBy(x: -rotate90, y:0, z: 0, duration: 0.3)]

        if isBomb {
            playerNode.runAction(SCNAction.playAudio(bombHitSound!, waitForCompletion: false))
            let deathSequence = SCNAction.sequence([fallInDirection[Int(arc4random_uniform(UInt32(fallInDirection.count)))],
                                                    SCNAction.fadeOut(duration: 1.0),
                                                    SCNAction.removeFromParentNode()])
            target.runAction(deathSequence)
        } else {
            target.runAction(SCNAction.playAudio(bulletHitSound!, waitForCompletion: false))
            let deathSequence = SCNAction.sequence([SCNAction.playAudio(pirateDeathSound!, waitForCompletion: false),
                                                    fallInDirection[Int(arc4random_uniform(UInt32(fallInDirection.count)))],
                                                    SCNAction.fadeOut(duration: 1.0),
                                                    SCNAction.removeFromParentNode()])
            target.runAction(deathSequence)
        }

        piratesShot += 1
        DispatchQueue.main.async {
            self.piratesLabel.text = "Pirates Shot: \(self.piratesShot)/\(self.piratesCreated)"
        }
    }

    private func position(node: SCNNode, atHit hit: ARHitTestResult) {
        node.transform = SCNMatrix4(hit.anchor!.transform)
        node.eulerAngles = SCNVector3Make(node.eulerAngles.x, node.eulerAngles.y, node.eulerAngles.z)

//        let position = SCNVector3Make(hit.worldTransform.columns.3.x + node.geometry!.boundingBox.min.z, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z)
//        print("Placing at \(hit.worldTransform.columns.3.x + node.geometry!.boundingBox.min.z), \(hit.worldTransform.columns.3.y), \(hit.worldTransform.columns.3.z)")
        let position = SCNVector3Make(hit.worldTransform.columns.3.x, hit.worldTransform.columns.3.y, hit.worldTransform.columns.3.z)
        node.position = position
    }

    func enemyFires(enemy: SCNNode, deviation: Float, bulletSpeed: Float) {
        let playerPosition = playerNode.worldPosition
        let enemyPosition = enemy.worldPosition

        let dx = playerPosition.x - enemyPosition.x
        let dz = playerPosition.z - enemyPosition.z
        let yAngle = atan2(dx, dz)
        enemy.runAction(SCNAction.rotateTo(x: 0, y: CGFloat(yAngle), z: 0, duration: 0.5, usesShortestUnitArc: true))

        var randomDeviation = randomFloatBetween(-deviation, and: deviation)
        if deviation == 0.0 {
            randomDeviation = 0.0
        }
        let impulse = SCNVector3(
            x: playerPosition.x - enemy.worldPosition.x + randomDeviation,
            y: playerPosition.y - enemy.worldPosition.y + randomDeviation,
            z: (playerPosition.z - enemy.worldPosition.z)
        )
        let projectile = EnemyProjectile()
        projectile.worldPosition = enemy.worldPosition

        sceneView?.scene.rootNode.addChildNode(projectile)
        projectile.runAction(SCNAction.playAudio(bulletFiredSound!, waitForCompletion: false))
        projectile.launch(inDirection: impulse)
    }

    @IBAction func tappedShoot(_ sender: Any) {
        if isGameActive {
            let camera = sceneView.session.currentFrame!.camera
            let projectile = Projectile()
            
            // transform to location of camera
            var translation = matrix_float4x4(projectile.transform)
            translation.columns.3.z = -0.1
            translation.columns.3.x = 0.0
            
            projectile.simdTransform = matrix_multiply(camera.transform, translation)
            
            //        let force = simd_make_float4(-1, 0, -3, 0)
            let force = simd_make_float4(0, 0, -2, 0)
            let rotatedForce = simd_mul(camera.transform, force)
            
            let impulse = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)
            
            sceneView?.scene.rootNode.addChildNode(projectile)
            projectile.runAction(SCNAction.playAudio(bulletFiredSound!, waitForCompletion: false))
            projectile.launch(inDirection: impulse)
        }
    }

    @IBAction func tappedBomb(_ sender: Any) {
        if isGameActive {
            if bombCount > 0 {
                let camera = sceneView.session.currentFrame!.camera
                let projectile = BombProjectile()
                
                // transform to location of camera
                var translation = matrix_float4x4(projectile.transform)
                translation.columns.3.z = -0.1
                translation.columns.3.x = 0.03
                
                projectile.simdTransform = matrix_multiply(camera.transform, translation)
                
                let force = simd_make_float4(-1.5, 0, -2, 0)
                let rotatedForce = simd_mul(camera.transform, force)
                
                let impulse = SCNVector3(rotatedForce.x, rotatedForce.y, rotatedForce.z)
                
                sceneView?.scene.rootNode.addChildNode(projectile)
                
                bombCount -= 1
                DispatchQueue.main.async {
                    self.bombsLabel.text = "Cannonballs: \(self.bombCount)"
                }
                projectile.runAction(SCNAction.playAudio(bombFiredSound!, waitForCompletion: false))
                projectile.launch(inDirection: impulse)
            }
        }
    }

    @IBAction func tappedScanGameArea(_ sender: Any) {
        var i = 1
        for timer in timers {
            print("stopping timer \(i)")
            i += 1
            timer.invalidate()
        }
        timers.removeAll()
        for target in targets {
            target.geometry = nil
            target.removeFromParentNode()
        }
        targets.removeAll()
//        sceneView?.scene.rootNode.enumerateChildNodes { (node, stop) in
//            if node.categoryBitMask != CollisionCategory.player.rawValue {
//                node.removeFromParentNode()
//            }
//        }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [ARSession.RunOptions.removeExistingAnchors, ARSession.RunOptions.resetTracking])
//        sceneManager.startPlaneDetection()
    }

    @IBAction func tappedStartGame(_ sender: Any) {
        var i = 1
        for timer in timers {
            print("stopping timer \(i)")
            i += 1
            timer.invalidate()
        }
        timers.removeAll()
        for target in targets {
            target.geometry = nil
            target.removeFromParentNode()
        }
        targets.removeAll()
        sceneManager.stopPlaneDetection()
        startNewGame()

        self.createRandomTarget()
        let timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: {_ in
            if (self.isGameActive) {
                if (self.piratesCreated % self.civilianAppearanceRate == 0 && self.isCivilianActive == false && self.isBossActive == false && self.isBossDefeated == false) {
                    self.createCivilian()
                }
                if (self.piratesCreated < self.pirateArmySize && self.isBossActive == false) {
                    self.createRandomTarget()
                }
                if (self.piratesCreated == self.pirateArmySize && self.isBossActive == false && self.isBossDefeated == false) {
                    self.createBoss()
                }
            }
        })
        timers.append(timer)
    }

    func getTargetVector(for target: SCNNode?) -> (SCNVector3, SCNVector3) {
        guard let target = target else { return (SCNVector3Zero, SCNVector3Zero) }
        
        let mat = target.presentation.transform // 4x4 transform matrix describing target node in world space
        let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of target node in world space
        let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of target node in world space
        
        return (dir, pos)
    }

    func getUserVector() -> (SCNVector3, SCNVector3) {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3Zero, SCNVector3Zero)
    }

    func getCameraVector() -> (SCNVector3, SCNVector3) {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(mat.m31, mat.m32, mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3Zero, SCNVector3Zero)
    }
    
    func getCameraPosition() -> SCNVector3 {
        let (_, position) = self.getCameraVector()
        return position
    }

}

struct CollisionCategory: OptionSet {
    let rawValue: Int

    static let none = CollisionCategory(rawValue: 1 << 1)
    static let bullet = CollisionCategory(rawValue: 1 << 2)
    static let bomb = CollisionCategory(rawValue: 1 << 3)
    static let target = CollisionCategory(rawValue: 1 << 4)
    static let enemyShot = CollisionCategory(rawValue: 1 << 5)
    static let player = CollisionCategory(rawValue: 1 << 6)
    static let civilian = CollisionCategory(rawValue: 1 << 7)
    static let boss = CollisionCategory(rawValue: 1 << 8)
}

func createMaterialFromImage(named: String) -> SCNMaterial {
    let material = SCNMaterial()
    material.diffuse.contents = UIImage(named: named)
    material.locksAmbientWithDiffuse = true
    return material
}

class EnemyTarget: SCNNode {
    var isAlive = true
    
    override init() {
        super.init()

        let box = SCNBox(width: 0.03, height: 0.06, length: 0.03, chamferRadius: 0.0)
        box.materials = [createMaterialFromImage(named: "pirate1_front"),
                         createMaterialFromImage(named: "pirate1_left"),
                         createMaterialFromImage(named: "pirate1_back"),
                         createMaterialFromImage(named: "pirate1_right"),
                         createMaterialFromImage(named: "pirate1_top"),
                         createMaterialFromImage(named: "pirate1_bottom")]
        geometry = box
        physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: box, options: nil))
        physicsBody?.categoryBitMask = CollisionCategory.target.rawValue
        physicsBody?.collisionBitMask = CollisionCategory.target.rawValue
        physicsBody?.contactTestBitMask = CollisionCategory.bullet.rawValue | CollisionCategory.bomb.rawValue

        // Set pivot point to bottom of node
        var minVec = SCNVector3Zero
        var maxVec = SCNVector3Zero
        (minVec, maxVec) = boundingBox
        pivot = SCNMatrix4MakeTranslation(minVec.x + (maxVec.x - minVec.x)/2, minVec.y, minVec.z + (maxVec.z - minVec.z)/2)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class EnemyProjectile: SCNNode {
    override init() {
        super.init()
        
        //        let capsule = SCNCapsule(capRadius: 0.006, height: 0.06)
        //        geometry = capsule
        let ball = SCNSphere(radius: 0.01)
        ball.firstMaterial?.lightingModel = .physicallyBased
        ball.firstMaterial?.diffuse.contents = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        geometry = ball

        eulerAngles = SCNVector3(CGFloat.pi / 2, (CGFloat.pi * 0.25), 0)
        
        physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ball, options: nil))
        physicsBody?.isAffectedByGravity = false
        physicsBody?.categoryBitMask = CollisionCategory.enemyShot.rawValue
        physicsBody?.collisionBitMask = CollisionCategory.player.rawValue
        physicsBody?.contactTestBitMask = CollisionCategory.player.rawValue
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func launch(inDirection direction: SCNVector3) {
        physicsBody?.applyForce(direction, asImpulse: true)
    }
}

class Projectile: SCNNode {
    override init() {
        super.init()

//        let capsule = SCNCapsule(capRadius: 0.006, height: 0.06)
//        geometry = capsule
        let ball = SCNSphere(radius: 0.005)
        ball.firstMaterial?.lightingModel = .physicallyBased
        ball.firstMaterial?.diffuse.contents = UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        geometry = ball

        eulerAngles = SCNVector3(CGFloat.pi / 2, (CGFloat.pi * 0.25), 0)

        physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ball, options: nil))
        physicsBody?.isAffectedByGravity = false
        physicsBody?.categoryBitMask = CollisionCategory.bullet.rawValue
        physicsBody?.contactTestBitMask = CollisionCategory.target.rawValue
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func launch(inDirection direction: SCNVector3) {
        physicsBody?.applyForce(direction, asImpulse: true)
    }
}

class BombProjectile: SCNNode {
    override init() {
        super.init()
        
        //        let capsule = SCNCapsule(capRadius: 0.006, height: 0.06)
        //        geometry = capsule
        let ball = SCNSphere(radius: 0.05)
        ball.firstMaterial?.lightingModel = .physicallyBased
        ball.firstMaterial?.diffuse.contents = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        geometry = ball

        eulerAngles = SCNVector3(CGFloat.pi / 2, (CGFloat.pi * 0.25), 0)

        physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ball, options: nil))
        physicsBody?.categoryBitMask = CollisionCategory.bomb.rawValue
        physicsBody?.collisionBitMask = CollisionCategory.target.rawValue
        physicsBody?.contactTestBitMask = CollisionCategory.target.rawValue
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func launch(inDirection direction: SCNVector3) {
        physicsBody?.applyForce(direction, asImpulse: true)
    }
}
