import Foundation
import Combine
import CoreLocation

enum SensorEvent {
    case audioLevel(Float)
    case breathing(Double)
    case movement(MovementType, Double)
    case proximity(Bool)
    case location(CLLocation)
    case faceExpression(FaceExpression, Bool)
    case battery(Float, Bool)
    case ambientLight(Double)
    case network(ssid: String?)
    case heartBeat
}

final class SensorHub: ObservableObject {
    static let shared = SensorHub()

    private let eventSubject = PassthroughSubject<SensorEvent, Never>()
    private var cancellables = Set<AnyCancellable>()

    var events: AnyPublisher<SensorEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    func bind(sensorManager: SensorManager,
              dataRecorder: DataRecorder,
              faceTracker: FaceTracker) {
        // Пульсированные события
        Timer.publish(every: 0.7, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.eventSubject.send(.heartBeat)
            }
            .store(in: &cancellables)

        // Движение
        sensorManager.$movementIntensity
            .combineLatest(sensorManager.$isMoving.map { $0 ? sensorManager.getMovementType() : .none })
            .throttle(for: .milliseconds(400), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] intensity, type in
                self?.eventSubject.send(.movement(type, intensity))
            }
            .store(in: &cancellables)

        // Аудио
        sensorManager.$audioLevel
            .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] level in
                self?.eventSubject.send(.audioLevel(level))
            }
            .store(in: &cancellables)

        sensorManager.$breathingRate
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] rate in
                self?.eventSubject.send(.breathing(rate))
            }
            .store(in: &cancellables)

        sensorManager.$proximityDetected
            .sink { [weak self] state in
                self?.eventSubject.send(.proximity(state))
            }
            .store(in: &cancellables)

        // Локация
        dataRecorder.$recordedData
            .compactMap { $0.currentLocation }
            .throttle(for: .seconds(3), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] location in
                self?.eventSubject.send(.location(location))
            }
            .store(in: &cancellables)

        // Лицо
        faceTracker.$faceExpression
            .combineLatest(faceTracker.$faceDetected)
            .sink { [weak self] expression, detected in
                self?.eventSubject.send(.faceExpression(expression, detected))
            }
            .store(in: &cancellables)
    }
}


