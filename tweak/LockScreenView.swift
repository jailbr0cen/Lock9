//
//  LockScreenView.swift
//  Lock9
//
//  Transparent overlay on the main lock screen page holding the slide to
//  unlock control and the camera grabber. Derived from SixLS by Skitty (GPLv3).
//

import UIKit

@objc final public class LockScreenView: UIView {
	let slideView = SlideUnlockView(frame: .zero)
	let cameraButton = UIImageView()

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundColor = .clear
		slideView.onUnlock = { [weak self] in self?.unlock() }
		addSubview(slideView)

		// the user's own camera.png (50x46 px, shipped as @2x)
		if let img = UIImage(contentsOfFile: "/var/jb/Library/Application Support/Lock9/camera@2x.png"),
		   let cg = img.cgImage {
			cameraButton.image = UIImage(cgImage: cg, scale: 2 / 1.3, orientation: .up) // shown 1.3x larger
		}
		cameraButton.contentMode = .bottomRight
		cameraButton.isUserInteractionEnabled = true
		cameraButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(cameraDragged(_:))))
		addSubview(cameraButton)
		NotificationCenter.default.addObserver(self, selector: #selector(applyPrefs),
											   name: Notification.Name("Lock9PrefsChanged"), object: nil)
		applyPrefs()
	}

	@objc func applyPrefs() {
		cameraButton.isHidden = !(Lock9Manager.sharedInstance()?.showCamera ?? true)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	public override func layoutSubviews() {
		super.layoutSubviews()
		let h: CGFloat = 70
		slideView.frame = CGRect(x: 0, y: bounds.height - 120, width: bounds.width, height: h)
		cameraButton.frame = CGRect(x: bounds.width - 64, y: bounds.height - 64, width: 60, height: 60)
	}

	// Only the slide area and camera take touches; everything else falls through.
	public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		let hit = super.hitTest(point, with: event)
		return hit === self ? nil : hit
	}

	@objc func present() {
		alpha = 1
		slideView.reset(animated: false)
		cameraButton.transform = .identity
		cameraButton.alpha = 1
	}

	@objc func presentAnimated() {
		slideView.reset(animated: true)
		UIView.animate(withDuration: 0.2) {
			self.cameraButton.transform = .identity
			self.cameraButton.alpha = 1
		}
	}

	@objc func unlock() {
		Lock9Manager.sharedInstance().unlock()
	}

	// MARK: camera swipe-up: the camera page rises from the bottom with the finger

	private var cameraPage: UIView?
	private var cameraProxy: UIImageView?
	private var cameraScroll: UIScrollView?
	private var iconTop0: CGFloat = 0

	private func screenH() -> CGFloat { return bounds.height }

	private func findCameraPage(in scroll: UIScrollView) -> UIView? {
		return scroll.subviews.first(where: {
			String(describing: type(of: $0)) == "CSPageViewBase" && abs($0.frame.origin.x - scroll.bounds.width) < 2
		})
	}

	// travel = how far the icon has moved up from its resting place
	private func applyCamera(travel: CGFloat) {
		guard let page = cameraPage, let scroll = cameraScroll, let proxy = cameraProxy else { return }
		let w = scroll.bounds.width
		let sheetTop = screenH() - travel
		page.transform = CGAffineTransform(translationX: -w, y: sheetTop)
		proxy.frame.origin.y = iconTop0 - travel
	}

	private func endCamera() {
		cameraPage?.transform = .identity
		if let page = cameraPage { cameraScroll?.sendSubviewToBack(page) }
		cameraProxy?.removeFromSuperview()
		cameraProxy = nil
		cameraPage = nil
		cameraScroll = nil
		cameraButton.alpha = 1
	}

	@objc func cameraDragged(_ gesture: UIPanGestureRecognizer) {
		let imgSize = cameraButton.image?.size ?? CGSize(width: 25, height: 23)
		iconTop0 = screenH() - 4 - imgSize.height
		let maxTravel = max(1, iconTop0 - screenH() / 8) // icon stops at the 1/8 mark
		let travel = min(max(0, -gesture.translation(in: self).y), maxTravel)

		switch gesture.state {
		case .began:
			guard let scroll = Lock9Manager.sharedInstance().csScrollView as UIScrollView?,
				  let page = findCameraPage(in: scroll) else { return }
			cameraScroll = scroll
			cameraPage = page
			page.isHidden = false
			page.alpha = 1
			scroll.bringSubviewToFront(page)
			let proxy = UIImageView(image: cameraButton.image)
			proxy.frame = CGRect(x: scroll.bounds.width - 4 - imgSize.width, y: iconTop0, width: imgSize.width, height: imgSize.height)
			scroll.addSubview(proxy)
			cameraProxy = proxy
			cameraButton.alpha = 0
			applyCamera(travel: 0)
		case .changed:
			applyCamera(travel: travel)
		case .ended:
			guard cameraPage != nil else { return }
			let vy = gesture.velocity(in: self).y
			if travel > maxTravel * 0.5 || vy < -800 {
				// finish: camera slides all the way up
				UIView.animate(withDuration: 0.2, animations: {
					self.cameraPage?.transform = CGAffineTransform(translationX: -(self.cameraScroll?.bounds.width ?? 0), y: 0)
					self.cameraProxy?.alpha = 0
				}, completion: { _ in
					// The sheet is black at this point. Cover the screen with black, put the
					// camera page back, and do a real animated scroll to it underneath, so the
					// cover sheet starts the camera app like it does for a normal swipe.
					let host = self.cameraScroll?.superview ?? self.cameraScroll
					let cover = UIView(frame: host?.bounds ?? .zero)
					cover.backgroundColor = .black
					host?.addSubview(cover)
					self.endCamera()
					var removed = false
					let removeCover = {
						if !removed {
							removed = true
							UIView.animate(withDuration: 0.15, animations: { cover.alpha = 0 }, completion: { _ in
								cover.removeFromSuperview()
							})
						}
					}
					Lock9Manager.sharedInstance().openCamera(completion: removeCover)
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: removeCover)
				})
			} else {
				UIView.animate(withDuration: 0.2, animations: {
					self.applyCamera(travel: 0)
				}, completion: { _ in
					self.endCamera()
				})
			}
		case .cancelled, .failed:
			if cameraPage != nil { endCamera() }
		default:
			break
		}
	}
}
