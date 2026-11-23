//
//  SlideUnlockView.swift
//  Lock9
//
//  iOS 7-9 style slide to unlock: only the chevron moves, and it "erases" the
//  glinty text as it passes over it. Derived from the glinty text handling of
//  SixLS (Skitty, GPLv3) and the look of NineUnlock (Minh Ton, MIT).
//

import UIKit

final class SlideUnlockView: UIView {
	let glinty: _UIGlintyStringView
	let chevronView = UIImageView()
	let textMask = CALayer()
	var onUnlock: (() -> Void)?

	private var font = UIFont.systemFont(ofSize: 24, weight: .light)
	private var text = "slide to unlock"
	private var glintColor = UIColor.white
	private let gap: CGFloat = 12      // chevron to text at rest
	private let padding: CGFloat = 4   // chevron to erase edge while sliding

	private var chevronW: CGFloat = 20
	private var startX: CGFloat = 0
	private var endX: CGFloat = 0
	private var chevronX: CGFloat = 0
	private var dragStartX: CGFloat = 0
	private var triggered = false

	private var displayLink: CADisplayLink?
	private var animFrom: CGFloat = 0
	private var animStart: CFTimeInterval = 0
	private var animDuration: CFTimeInterval = 0.3

	override init(frame: CGRect) {
		glinty = _UIGlintyStringView(text: "slide to unlock", andFont: UIFont.systemFont(ofSize: 24, weight: .light))
		glinty.setChevronStyle(0)
		super.init(frame: frame)

		addSubview(glinty)
		glinty.show()
		textMask.backgroundColor = UIColor.black.cgColor
		glinty.layer.mask = textMask

		chevronView.image = SlideUnlockView.makeChevron(font: font)
		chevronView.contentMode = .scaleAspectFit
		addSubview(chevronView)

		applyPrefs()

		addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
		NotificationCenter.default.addObserver(self, selector: #selector(applyPrefs),
											   name: Notification.Name("Lock9PrefsChanged"), object: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: preferences

	static func color(fromHex hex: String) -> UIColor? {
		var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		if s.hasPrefix("#") { s.removeFirst() }
		guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
		return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
					   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
	}

	@objc func applyPrefs() {
		let mgr = Lock9Manager.sharedInstance()
		text = (mgr?.slideText?.isEmpty ?? true) ? "slide to unlock" : mgr!.slideText!
		let size = (mgr?.textSize ?? 0) > 0 ? mgr!.textSize : 24
		font = UIFont.systemFont(ofSize: size, weight: .light)
		glintColor = SlideUnlockView.color(fromHex: mgr?.textColorHex ?? "#FFFFFF") ?? .white

		glinty.font = font
		glinty.text = text
		glinty.updateText()
		chevronView.image = SlideUnlockView.makeChevron(font: font)
		chevronView.tintColor = glintColor.withAlphaComponent(0.85)
		fixTextColor()
		setNeedsLayout()
	}

	// Try the system chevron image, fall back to an SF Symbol
	static func makeChevron(font: UIFont) -> UIImage? {
		if let helper = _UIGlintyStringView(text: "x", andFont: font) {
			helper.setChevronStyle(1)
			if let img = helper.value(forKey: "chevron") as? UIImage, img.size.width > 1 {
				return img.withRenderingMode(.alwaysTemplate)
			}
		}
		let cfg = UIImage.SymbolConfiguration(pointSize: font.pointSize + 2, weight: .semibold)
		return UIImage(systemName: "chevron.right", withConfiguration: cfg)?.withRenderingMode(.alwaysTemplate)
	}

	// MARK: layout

	override func layoutSubviews() {
		super.layoutSubviews()
		let textW = (text as NSString).size(withAttributes: [.font: font]).width
		let imgH = chevronView.image?.size.height ?? 30
		chevronW = chevronView.image?.size.width ?? 20

		let total = chevronW + gap + textW
		let groupLeft = (bounds.width - total) / 2
		let textLeft = groupLeft + chevronW + gap
		startX = groupLeft
		endX = textLeft + textW - chevronW - padding + 2

		// glinty centers its text, so offset the frame to put the text at textLeft
		glinty.frame = CGRect(x: textLeft + textW / 2 - bounds.width / 2, y: 0, width: bounds.width, height: bounds.height)

		chevronView.bounds = CGRect(x: 0, y: 0, width: chevronW, height: imgH)
		if !triggered && displayLink == nil { chevronX = startX }
		applyChevron(x: max(chevronX, startX))
	}

	private func applyChevron(x: CGFloat) {
		chevronX = x
		chevronView.center = CGPoint(x: x + chevronW / 2, y: bounds.height / 2)
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		if x <= startX + 0.5 {
			// at rest the whole text shows
			textMask.frame = CGRect(x: -2000, y: 0, width: glinty.bounds.width + 4000, height: glinty.bounds.height)
		} else {
			// text is only visible to the right of the chevron (plus padding)
			let maskLeft = x + chevronW + padding - glinty.frame.origin.x
			textMask.frame = CGRect(x: maskLeft, y: 0, width: max(0, glinty.bounds.width - maskLeft + 2000), height: glinty.bounds.height)
		}
		CATransaction.commit()
	}

	override func didMoveToWindow() {
		super.didMoveToWindow()
		if window != nil {
			glinty.hide()
			glinty.show()
		}
	}

	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		fixTextColor()
	}

	// Same trick as SixLS/NineUnlock: recolor the glint layer
	func fixTextColor() {
		let color = glintColor.withAlphaComponent(0.65).cgColor
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			let l1 = self.glinty.layer.sublayers?.first?.sublayers
			if let l1 = l1, l1.count > 2 {
				l1[2].backgroundColor = color
			}
		}
	}

	// MARK: reset / animation

	private func stopAnimation() {
		displayLink?.invalidate()
		displayLink = nil
	}

	func reset(animated: Bool) {
		triggered = false
		stopAnimation()
		if animated && chevronX > startX + 0.5 {
			animFrom = chevronX
			animStart = CACurrentMediaTime()
			let progress = Double((chevronX - startX) / max(1, endX - startX))
			animDuration = 0.28 + 0.22 * progress
			let link = CADisplayLink(target: self, selector: #selector(tick))
			link.add(to: .main, forMode: .common)
			displayLink = link
		} else {
			applyChevron(x: startX)
		}
	}

	@objc private func tick() {
		let t = min(1, (CACurrentMediaTime() - animStart) / animDuration)
		let eased = 1 - pow(1 - CGFloat(t), 3) // ease-out cubic
		applyChevron(x: animFrom + (startX - animFrom) * eased)
		if t >= 1 { stopAnimation() }
	}

	@objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
		switch gesture.state {
		case .began:
			stopAnimation()
			dragStartX = chevronX
		case .changed:
			if triggered { return }
			let x = min(max(dragStartX + gesture.translation(in: self).x, startX), endX)
			applyChevron(x: x)
			if x >= endX - 0.5 {
				// the chevron has erased all of the text
				triggered = true
				gesture.isEnabled = false
				gesture.isEnabled = true
				onUnlock?()
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
					self.reset(animated: false)
				}
			}
		case .ended, .cancelled, .failed:
			if !triggered { reset(animated: true) }
		default:
			break
		}
	}
}
